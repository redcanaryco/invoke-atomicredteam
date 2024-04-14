function Invoke-SetupAtomicRunner {

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
        # Check if current user has passwordless sudo privleges. If not, attempt to configure it for current user.
        $can_sudo = Set-Sudo($true)
        if ($can_sudo -eq $true -and (sudo id -u) -ne 0 ) {
            Throw "You must run the Invoke-SetupAtomicRunner script as root"
            exit
        }
        elseif ($can_sudo -eq $false -and (id -u) -ne 0 ) {
            Throw "You must run the Invoke-SetupAtomicRunner script as root"
            exit
        }
    }

    if ($artConfig.basehostname.length -gt 15) { Throw "The hostname for this machine (minus the GUID) must be 15 characters or less. Please rename this computer." }

    #create AtomicRunner-Logs directories if they don't exist
    New-Item -ItemType Directory $artConfig.atomicLogsPath -ErrorAction Ignore
    New-Item -ItemType Directory $artConfig.runnerFolder -ErrorAction Ignore

    if ($artConfig.gmsaAccount) {
        Start-Service WinRM
        $path = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules\RenameRunner\RoleCapabilities"
        New-Item -ItemType Directory $path -ErrorAction Ignore
        New-PSSessionConfigurationFile -SessionType RestrictedRemoteServer -GroupManagedServiceAccount $artConfig.gmsaAccount -RoleDefinitions @{ "$($artConfig.user)" = @{ 'RoleCapabilities' = 'RenameRunner' } } -path "$env:Temp\RenameRunner.pssc"
        New-PSRoleCapabilityFile -VisibleCmdlets @{ 'Name' = 'Rename-Computer'; 'Parameters' = @{ 'Name' = 'NewName'; 'ValidatePattern' = 'ATOMICSOC.*' }, @{ 'Name' = 'Force' }, @{ 'Name' = 'restart' } } -path "$path\RenameRunner.psrc"
        $null = Register-PSSessionConfiguration -name "RenameRunnerEndpoint" -path "$env:Temp\RenameRunner.pssc" -force
        Add-LocalGroupMember "administrators" "$($artConfig.gmsaAccount)$" -ErrorAction Ignore
        # Make sure WinRM is enabled and set to Automic start (not delayed)
        Set-ItemProperty hklm:\\SYSTEM\CurrentControlSet\Services\WinRM -Name Start -Value 2
        Set-ItemProperty hklm:\\SYSTEM\CurrentControlSet\Services\WinRM -Name DelayedAutostart -Value 0 # default is delayed start and that is too slow given our 1 minute delay on our kickoff task
        # this registry key must be set to zero for things to work get-itemproperty hklm:\Software\Policies\Microsoft\Windows\WinRM\Service\
        $hklmKey = (get-itemproperty hklm:\Software\Policies\Microsoft\Windows\WinRM\Service -name DisableRunAs -ErrorAction ignore).DisableRunAs
        $hkcuKey = (get-itemproperty hkcu:\Software\Policies\Microsoft\Windows\WinRM\Service -name DisableRunAs -ErrorAction ignore).DisableRunAs
        if ((1 -eq $hklmKey) -or (1 -eq $hkcuKey)) { Write-Host -ForegroundColor Red "DisableRunAs registry Key will not allow use of the JEA endpoint with a gmsa account" }
        if ((Get-ItemProperty hklm:\System\CurrentControlSet\Control\Lsa\ -name DisableDomainCreds).DisableDomainCreds) { Write-Host -ForegroundColor Red "Do not allow storage of passwords and credentials for network authentication must be disabled" }
    }

    if ($artConfig.OS -eq "windows") {

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
    }
    else {

        # sets cronjob string using basepath from config.ps1
        $pwshPath = which pwsh
        $job = "@reboot $env:USER sleep 60;$pwshPath -Command Invoke-KickoffAtomicRunner"
        $exists = cat /etc/crontab | Select-String -Quiet "KickoffAtomicRunner"
        #checks if the Kickoff-AtomicRunner job exists. If not appends it to the system crontab.
        if ($null -eq $exists -and $can_sudo -eq $true) {
            $(Write-Output "$job" | sudo tee -a /etc/crontab)
            write-host "setting cronjob"
        }
        elseif ($null -eq $exists -and $can_sudo -eq $false) {
            $(Write-Output "$job" >> /etc/crontab)
            write-host "setting cronjob"
            }
        else {
            write-host "cronjob already exists"
        }
    }

    # Add Import-Module statement to the PowerShell profile
    $root = Split-Path $PSScriptRoot -Parent
    if($IsLinux -or $IsMacOS){
        mkdir (Split-Path $PROFILE)
        touch $PROFILE
    }
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
