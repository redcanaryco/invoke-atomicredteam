function Invoke-SetupAtomicRunner {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]
        $SkipServiceSetup,

        [Parameter(Mandatory = $false)]
        [switch]
        $asScheduledtask
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
        if ($asScheduledtask) {
            if (Test-Path $artConfig.credFile) {
                Write-Host "Credential File $($artConfig.credFile) already exists, not prompting for creation of a new one."
                $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $artConfig.user, (Get-Content $artConfig.credFile | ConvertTo-SecureString)
            }
            else {
                # create credential file for the user since we aren't using a group managed service account
                $cred = Get-Credential -UserName $artConfig.user -message "Enter password for $($artConfig.user) in order to create the runner scheduled task"
                $cred.Password | ConvertFrom-SecureString | Out-File $artConfig.credFile
            }
            # setup scheduled task that will start the runner after each restart
            # local security policy --> Local Policies --> Security Options --> Network access: Do not allow storage of passwords and credentials for network authentication must be disabled
            $taskName = "KickOff-AtomicRunner"
            Unregister-ScheduledTask $taskName -confirm:$false -ErrorAction Ignore
            # Windows scheduled task includes a 20 minutes sleep then restart if the call to Invoke-KickoffAtomicRunner fails
            # this occurs occassionally when Windows has issues logging into the runner user's account and logs in as a TEMP user
            $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-exec bypass -Command Invoke-KickoffAtomicRunner; Start-Sleep 1200; Restart-Computer -Force"
            $taskPrincipal = New-ScheduledTaskPrincipal -UserId $artConfig.user
            $delays = @(1, 2, 4, 8, 16, 32, 64) # using multiple triggers as a retry mechanism because the built-in retry mechanism doesn't work when the computer renaming causes AD replication delays
            $triggers = @()
            foreach ($delay in $delays) {
                $trigger = New-ScheduledTaskTrigger -AtStartup
                $trigger.Delay = "PT$delay`M"
                $triggers += $trigger
            }
            $task = New-ScheduledTask -Action $taskAction -Principal $taskPrincipal -Trigger $triggers -Description "A task that runs 1 minute or later after boot to start the atomic test runner script"
            try {
                $null = Register-ScheduledTask -TaskName $taskName -InputObject $task -User $artConfig.user -Password $($cred.GetNetworkCredential().password) -ErrorAction Stop
            }
            catch {
                if ($_.CategoryInfo.Category -eq "AuthenticationError") {
                    # remove the credential file if the password didn't work
                    Write-Error "The credentials you entered are incorrect. Please run the setup script again and double check the username and password."
                    Remove-Item $artConfig.credFile
                }
                else {
                    Throw $_
                }
            }

            # remove the atomicrunnerservice now that we are using a scheduled task instead
            . "$PSScriptRoot\AtomicRunnerService.ps1" -Remove
        }
        elseif (-not $SkipServiceSetup) {
            # create the service that will start the runner after each restart
            # The user must have the "Log on as a service" right. To add that right, open the Local Security Policy management console, go to the
            # "\Security Settings\Local Policies\User Rights Assignments" folder, and edit the "Log on as a service" policy there.
            . "$PSScriptRoot\AtomicRunnerService.ps1" -Remove
            . "$PSScriptRoot\AtomicRunnerService.ps1" -UserName $artConfig.user -installDir $artConfig.serviceInstallDir -Setup
            Add-EnvPath -Container Machine -Path $artConfig.serviceInstallDir
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

            # remove scheduled task now that we are using a service instead
            Unregister-ScheduledTask "KickOff-AtomicRunner" -confirm:$false -ErrorAction Ignore
        }
    }
    else {
        # sets cronjob string using basepath from config.ps1
        $pwshPath = which pwsh
        $job = "@reboot root sleep 60;$pwshPath -Command Invoke-KickoffAtomicRunner"
        $exists = cat /etc/crontab | Select-String -Quiet "KickoffAtomicRunner"
        #checks if the Kickoff-AtomicRunner job exists. If not appends it to the system crontab.
        if ($null -eq $exists) {
            $(Write-Output "$job" >> /etc/crontab)
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
    $profileFolder = Split-Path $profile
    New-Item -ItemType Directory -Force -Path $profileFolder | Out-Null
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

# Add-EnvPath from https://gist.github.com/mkropat/c1226e0cc2ca941b23a9
function Add-EnvPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [ValidateSet('Machine', 'User', 'Session')]
        [string] $Container = 'Session'
    )

    if ($Container -ne 'Session') {
        $containerMapping = @{
            Machine = [EnvironmentVariableTarget]::Machine
            User    = [EnvironmentVariableTarget]::User
        }
        $containerType = $containerMapping[$Container]

        $persistedPaths = [Environment]::GetEnvironmentVariable('Path', $containerType) -split ';'
        if ($persistedPaths -notcontains $Path) {
            $persistedPaths = $persistedPaths + $Path | Where-Object { $_ }
            [Environment]::SetEnvironmentVariable('Path', $persistedPaths -join ';', $containerType)
        }
    }

    $envPaths = $env:Path -split ';'
    if ($envPaths -notcontains $Path) {
        $envPaths = $envPaths + $Path | Where-Object { $_ }
        $env:Path = $envPaths -join ';'
    }
}