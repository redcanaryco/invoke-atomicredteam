function Invoke-SetupAtomicRunner {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]
        $SkipServiceSetup       
    )

    # ensure running with admin privs
    if ($artConfig.OS -eq "windows") {
        # auto-elevate on Windows
        $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
        $testadmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
        if ($testadmin -eq $false) {
            Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
            exit $LASTEXITCODE
        }
    }
    else {
        # linux and macos check - doesn't auto-elevate
        if ((id -u) -ne 0 ) {
            Throw "You must run the Invoke-SetupAtomicRunner script as root"
            exit
        }
    }

    if ($artConfig.basehostname.length -gt 15) { Throw "The hostname for this machine (minus the GUID) must be 15 characters or less. Please rename this computer." }

    #create AtomicRunner-Logs directories if they don't exist
    New-Item -ItemType Directory $artConfig.atomicLogsPath -ErrorAction Ignore
    New-Item -ItemType Directory $artConfig.runnerFolder -ErrorAction Ignore

    if ($artConfig.OS -eq "windows") {
        if (-not $SkipServiceSetup) {
            # create the service that will start the runner after each restart
            # The user must have the "Log on as a service" right. To add that right, open the Local Security Policy management console, go to the
            # "\Security Settings\Local Policies\User Rights Assignments" folder, and edit the "Log on as a service" policy there.
            . "$PSScriptRoot\AtomicRunnerService.ps1" -Remove
            . "$PSScriptRoot\AtomicRunnerService.ps1" -UserName $artConfig.user -Setup
            # set service start retry options
            $ServiceDisplayName = "AtomicRunnerService"
            $action1, $action2, $action3 = "restart"
            $time1 = 600000 # 10 minutes in miliseconds
            $action2 = "restart"
            $time2 = 600000 # 10 minutes in miliseconds
            $actionLast = "restart"
            $timeLast = 3600000 # 1 hour in miliseconds
            $resetCounter = 86400 # 1 day in seconds 
            $services = Get-CimInstance -ClassName 'Win32_Service' | Where-Object { $_.DisplayName -imatch $ServiceDisplayName }
            $action = $action1 + "/" + $time1 + "/" + $action2 + "/" + $time2 + "/" + $actionLast + "/" + $timeLast
            foreach ($service in $services) {
                # https://technet.microsoft.com/en-us/library/cc742019.aspx
                $output = sc.exe  failure $($service.Name) actions= $action reset= $resetCounter
            }
            # set service to delayed auto-start (doesn't reflect in the services console until after a reboot)
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\AtomicRunnerService" -Name Start -Value 2
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\AtomicRunnerService" -Name DelayedAutostart -Value 1
        }

        # remove scheduled task now that we are using a service instead
        Unregister-ScheduledTask "KickOff-AtomicRunner" -confirm:$false -ErrorAction Ignore
    }
    else {
        # sets cronjob string using basepath from config.ps1
        $pwshPath = which pwsh
        $job = "@reboot root sleep 60;$pwshPath -Command Invoke-KickoffAtomicRunner"
        $exists = cat /etc/crontab | Select-String -Quiet "KickoffAtomicRunner"
        #checks if the Kickoff-AtomicRunner job exists. If not appends it to the system crontab.
        if ($null -eq $exists) {
            $(echo "$job" >> /etc/crontab)
            write-host "setting cronjob"
        }
        else {
            write-host "cronjob already exists"
        }
    }

    # Add Import-Module statement to the PowerShell profile
    $root = Split-Path $PSScriptRoot -Parent
    $pathToPSD1 = Join-Path $root "Invoke-AtomicRedTeam.psd1"
    $importStatement = "Import-Module ""$pathToPSD1"" -Force"
    New-Item $PROFILE -ErrorAction Ignore
    $profileContent = Get-Content $profile
    $line = $profileContent | Select-String ".*import-module.*invoke-atomicredTeam.psd1" | Select-Object -ExpandProperty Line
    if ($line) {
        $profileContent | ForEach-Object { $_.replace( $line, "$importStatement") } | Set-Content $profile
    }
    else {
        Add-Content $profile $importStatement
    }
    
    # Install the Posh-SYLOG module if we are configured to use it and it is not already installed
    if ((-not (Get-Module -ListAvailable "Posh-SYSLOG")) -and [bool]$artConfig.syslogServer -and [bool]$artConfig.syslogPort) {
        write-verbose "Posh-SYSLOG"
        Install-Module -Name Posh-SYSLOG -Scope CurrentUser -Force
    }

    # create the CSV schedule of atomics to run if it doesn't exist
    if (-not (Test-Path $artConfig.scheduleFile)) {
        Invoke-GenerateNewSchedule
    }

    $schedule = Get-Schedule
    if ($null -eq $schedule) {
        Write-Host -ForegroundColor Yellow "There are no tests enabled on the schedule, set the 'Enabled' column to 'True' for the atomic test that you want to run. The schedule file is found here: $($artConfig.scheduleFile)"
        Write-Host -ForegroundColor Yellow "Rerun this setup script after updating the schedule"
    }
    else {
        # Get the prereqs for all of the tests on the schedule
        Invoke-AtomicRunner -GetPrereqs
    }
}
