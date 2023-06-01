. "$PSScriptRoot\Invoke-RunnerScheduleMethods.ps1"

function Invoke-AtomicRunner {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]
        $ShowDetails,

        [Parameter(Mandatory = $false)]
        [switch]
        $CheckPrereqs,

        [Parameter(Mandatory = $false)]
        [switch]
        $GetPrereqs,

        [Parameter(Mandatory = $false)]
        [switch]
        $Cleanup,

        [Parameter(Mandatory = $false)]
        [switch]
        $ShowDetailsBrief,

        [Parameter(Mandatory = $false)]
        [String]
        $LoggingModule,

        [Parameter(Mandatory = $false)]
        $listOfAtomics,

        [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
        $OtherArgs
    )
    Begin { }
    Process {       

        function Get-GuidFromHostName( $basehostname ) {
            $guid = [System.Net.Dns]::GetHostName() -replace $($basehostname + "-"), ""

            if (!$guid) {
                LogRunnerMsg "Hostname has not been updated or could not parse out the Guid: " + $guid
                return
            }
            
            # Confirm hostname contains a guid
            [regex]$guidRegex = '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'

            if ($guid -match $guidRegex) { return $guid } else { return "" }
        }

        function Invoke-AtomicTestFromScheduleRow ($tr, $Cleanup = $false) {
            $theArgs = $tr.InputArgs
            if ($theArgs.GetType().Name -ne "Hashtable") {
                $tr.InputArgs = ConvertFrom-StringData -StringData $theArgs
            }
            $sc = $tr.AtomicsFolder
            #Run the Test based on if scheduleContext is 'private' or 'public'
            if (($sc -eq 'public') -or ($null -eq $sc)) {
                Invoke-AtomicTest $tr.Technique -TestGuids $tr.auto_generated_guid -InputArgs $tr.InputArgs -TimeoutSeconds $tr.TimeoutSeconds -ExecutionLogPath $artConfig.execLogPath -PathToAtomicsFolder $artConfig.PathToPublicAtomicsFolder @htvars -Cleanup:$Cleanup
            }
            elseif ($sc -eq 'private') {
                Invoke-AtomicTest $tr.Technique -TestGuids $tr.auto_generated_guid -InputArgs $tr.InputArgs -TimeoutSeconds $tr.TimeoutSeconds -ExecutionLogPath $artConfig.execLogPath -PathToAtomicsFolder $artConfig.PathToPrivateAtomicsFolder @htvars -Cleanup:$Cleanup
            }
        }

        function Rename-ThisComputer ($tr, $basehostname) {
            $hash = $tr.auto_generated_guid

            #Todo: do we need this cred thing if using a gMSA?
            $newHostName = "$basehostname-$hash"
            if ($artConfig.verbose) { LogRunnerMsg "Setting hostname to $newHostName" }

            If (Test-Path $artConfig.stopFile) {
                LogRunnerMsg "exiting script because $($artConfig.stopFile) exists"
                exit
            }

            if ($IsLinux) {
                Invoke-Expression $("hostnamectl set-hostname $newHostName")
                Invoke-Expression $("shutdown -r now")
            }
            if ($IsMacOS) {
                Invoke-Expression $("/usr/sbin/scutil --set HostName $newHostName")
                Invoke-Expression $("/usr/sbin/scutil --set ComputerName $newHostName")
                Invoke-Expression $("/usr/sbin/scutil --set LocalHostName $newHostName")
                Invoke-Expression $("/sbin/shutdown -r now")
            }
            else {
                if ($debug) { LogRunnerMsg "Debug: pretending to rename the computer to $newHostName"; exit }
                if ($artConfig.gmsaAccount) {
                    $retry = $true; $count = 0
                    while ($retry) {
                        # add retry loop to avoid this occassional error "The verification of the MSA failed with error 1355"
                        Invoke-Command -ComputerName '127.0.0.1' -ConfigurationName 'RenameRunnerEndpoint' -ScriptBlock { Rename-Computer -NewName $Using:newHostName -Force -Restart }
                        Start-Sleep 120; $count = $count + 1
                        if ($count -gt 15) { $retry = $false }
                    }
                }
                else {
                    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $artConfig.user, (Get-Content $artConfig.credFile | ConvertTo-SecureString)
                    try {
                        Rename-Computer -NewName $newHostName -Force -DomainCredential $cred -Restart -ErrorAction stop
                    }
                    catch {
                        if ($artConfig.verbose) { LogRunnerMsg $_ }
                        try { Rename-Computer -NewName $newHostName -Force -LocalCredential $cred -Restart -ErrorAction stop } catch { if ($artConfig.verbose) { LogRunnerMsg $_ } }
                    }
                }
                Start-Sleep -seconds 30
                LogRunnerMsg "uh oh, still haven't restarted - should never get to here"
                exit
            }
            
        }
        
        function Get-TimingVariable ($sched) {
            $atcount = $sched.Count
            if ($null -eq $atcount) { $atcount = 1 }
            $scheduleTimeSpanSeconds = $artConfig.scheduleTimeSpan.TotalSeconds
            $secondsForAllTestsToComplete = $scheduleTimeSpanSeconds
            $sleeptime = ($secondsForAllTestsToComplete / $atcount) - 120 - $artConfig.kickOffDelay.TotalSeconds # 1 minute for restart and 1 minute delay for scheduled task and an optional kickoff delay
            if ($sleeptime -lt 120) { $sleeptime = 120 } # minimum 2 minute sleep time
            return $sleeptime
        }

        # Convert OtherArgs to hashtable so we can pass it through to the call to Invoke-AtomicTest
        $htvars = @{}
        if ($OtherArgs) {
            $OtherArgs | ForEach-Object {
                if ($_ -match '^-') {
                    #New parameter
                    $lastvar = $_ -replace '^-'
                    $htvars[$lastvar] = $true
                }
                else {
                    #Value
                    $htvars[$lastvar] = $_
                }
            }
        }

        $htvars += [Hashtable]$PSBoundParameters
        $htvars.Remove('listOfAtomics') | Out-Null
        $htvars.Remove('OtherArgs') | Out-Null
        $htvars.Remove('Cleanup') | Out-Null

        $schedule = Get-Schedule $listOfAtomics
        # If the schedule is empty, end process
        if (-not $schedule) {
            LogRunnerMsg "No test guid's or enabled tests."
            return
        }

        # timing variables
        $SleepTillCleanup = Get-TimingVariable $schedule

        # Perform cleanup, Showdetails or Prereq stuff for all scheduled items and then exit
        if ($Cleanup -or $ShowDetails -or $CheckPrereqs -or $ShowDetailsBrief -or $GetPrereqs -or $listOfAtomics) {
            $schedule | ForEach-Object {
                Invoke-AtomicTestFromScheduleRow $_ $Cleanup
            }
            return
        }

        # exit if file stop.txt is found
        If (Test-Path $artConfig.stopFile) {
            LogRunnerMsg "exiting script because $($artConfig.stopFile) does exist"
            Write-Host -ForegroundColor Yellow "Exiting script because $($artConfig.stopFile) does exist."; Start-Sleep 10;
            exit
        }
        
        # Find current test to run
        $guid = Get-GuidFromHostName $artConfig.basehostname
        if ([string]::IsNullOrWhiteSpace($guid)) {
            LogRunnerMsg "Test Guid ($guid) was null, using next item in the schedule"
        }
        else {
            if ($artConfig.verbose) { LogRunnerMsg "Found Test: $guid specified in hostname" }
            $sp = [Collections.Generic.List[Object]]$schedule
            $currentIndex = $sp.FindIndex( { $args[0].auto_generated_guid -eq $guid })
            if (($null -ne $currentIndex) -and ($currentIndex -ne -1)) {
                $tr = $schedule[$currentIndex]
            }

            if ($null -ne $tr) {
                Invoke-AtomicTestFromScheduleRow $tr
                Write-Host -Fore cyan "Sleeping for $SleepTillCleanup seconds before cleaning up"; Start-Sleep -Seconds $SleepTillCleanup
                
                # Cleanup after running test
                Invoke-AtomicTestFromScheduleRow $tr $true
            }
            else {
                LogRunnerMsg "Could not find Test: $guid in schedule. Please update schedule to run this test."
            }
        }

        # Load next scheduled test before renaming computer
        $nextIndex += $currentIndex + 1     
        if ($nextIndex -ge ($schedule.count)) {
            $tr = $schedule[0]
        }
        else {
            $tr = $schedule[$nextIndex]
        }
        
        if ($null -eq $tr) { 
            LogRunnerMsg "Could not determine the next row to execute from the schedule, Starting from 1st row"; 
            $tr = $schedule[0] 
        }

        #Rename Computer and Restart
        Rename-ThisComputer $tr $artConfig.basehostname
    
    }
}
