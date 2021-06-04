<#
.SYNOPSIS
    Invokes specified Atomic test(s)
.DESCRIPTION
    Invokes specified Atomic tests(s).  Optionally, you can specify if you want to list the details of the Atomic test(s) only.
.EXAMPLE Check if Prerequisites for Atomic Test are met
    PS/> Invoke-AtomicTest T1117 -CheckPrereqs
.EXAMPLE Invokes Atomic Test
    PS/> Invoke-AtomicTest T1117
.EXAMPLE Run the Cleanup Commmand for the given Atomic Test
    PS/> Invoke-AtomicTest T1117 -Cleanup
.EXAMPLE Generate Atomic Test (Output Test Definition Details)
    PS/> Invoke-AtomicTest T1117 -ShowDetails
.EXAMPLE Invoke a test and flow the standard/error output to the console
    PS/> Invoke-AtomicTest T1117 -Interactive
.EXAMPLE Invoke a test and keep standard/error output files for later processing. This edge case has specific requirements. See https://github.com/redcanaryco/invoke-atomicredteam/issues/60
    PS/> Invoke-AtomicTest T1117 -KeepStdOutStdErrFiles
.NOTES
    Create Atomic Tests from yaml files described in Atomic Red Team. https://github.com/redcanaryco/atomic-red-team/tree/master/atomics
.LINK
    Installation and Usage Wiki: https://github.com/redcanaryco/invoke-atomicredteam/wiki
    Github repo: https://github.com/redcanaryco/invoke-atomicredteam
#>
function Invoke-AtomicTest {
    [CmdletBinding(DefaultParameterSetName = 'technique',
        SupportsShouldProcess = $true,
        PositionalBinding = $false,
        ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [ValidateNotNullOrEmpty()]
        [String]
        $AtomicTechnique,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $ShowDetails,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $ShowDetailsBrief,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [String[]]
        $TestNumbers,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [String[]]
        $TestNames,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [String[]]
        $TestGuids,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [String]
        $PathToAtomicsFolder = $( if ($IsLinux -or $IsMacOS) { $Env:HOME + "/AtomicRedTeam/atomics" } else { $env:HOMEDRIVE + "\AtomicRedTeam\atomics" }),

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $CheckPrereqs = $false,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $PromptForInputArgs = $false,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $GetPrereqs = $false,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $Cleanup = $false,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [switch]
        $NoExecutionLog = $false,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [String]
        $ExecutionLogPath = $( if ($IsLinux -or $IsMacOS) { "/tmp/Invoke-AtomicTest-ExecutionLog.csv" } else { "$env:TEMP\Invoke-AtomicTest-ExecutionLog.csv" }),

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [switch]
        $Force,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [HashTable]
        $InputArgs,
    
        [Parameter(Mandatory = $false,
            ParameterSetName = 'technique')]
        [Int]
        $TimeoutSeconds = 120,

        [Parameter(Mandatory = $false, ParameterSetName = 'technique')]
        [System.Management.Automation.Runspaces.PSSession[]]$Session,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $Interactive = $false,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'technique')]
        [switch]
        $KeepStdOutStdErrFiles = $false

    )
    BEGIN { } # Intentionally left blank and can be removed
    PROCESS {
        $PathToAtomicsFolder = (Resolve-Path $PathToAtomicsFolder).Path
        
        Write-Verbose -Message 'Attempting to run Atomic Techniques'
        Write-Host -ForegroundColor Cyan "PathToAtomicsFolder = $PathToAtomicsFolder`n"
        
        $targetPlatform, $isElevated, $tmpDir, $targetHostname, $targetUser = Get-TargetInfo $Session
        $PathToPayloads = if ($Session) { "$tmpDir`AtomicRedTeam" }  else { $PathToAtomicsFolder }

        function Invoke-AtomicTestSingle ($AT) {

            $AT = $AT.ToUpper()
            $pathToYaml = Join-Path $PathToAtomicsFolder "\$AT\$AT.yaml"
            if (Test-Path -Path $pathToYaml) { $AtomicTechniqueHash = Get-AtomicTechnique -Path $pathToYaml }
            else {
                Write-Host -Fore Red "ERROR: $PathToYaml does not exist`nCheck your Atomic Number and your PathToAtomicsFolder parameter"
                return
            }
            $techniqueCount = 0

            foreach ($technique in $AtomicTechniqueHash) {

                $techniqueCount++

                $props = @{
                    Activity        = "Running $($technique.display_name.ToString()) Technique"
                    Status          = 'Progress:'
                    PercentComplete = ($techniqueCount / ($AtomicTechniqueHash).Count * 100)
                }
                Write-Progress @props

                Write-Debug -Message "Gathering tests for Technique $technique"

                $testCount = 0
                foreach ($test in $technique.atomic_tests) {

                    Write-Verbose -Message 'Determining tests for target operating system'

                    $testCount++

                    if (-Not $test.supported_platforms.Contains($targetPlatform)) {
                        Write-Verbose -Message "Unable to run non-$targetPlatform tests"
                        continue
                    }

                    if ($null -ne $TestNumbers) {
                        if (-Not ($TestNumbers -contains $testCount) ) { continue }
                    }

                    if ($null -ne $TestNames) {
                        if (-Not ($TestNames -contains $test.name) ) { continue }
                    }

                    if ($null -ne $TestGuids) {
                        if (-Not ($TestGuids -contains $test.auto_generated_guid) ) { continue }
                    }

                    $props = @{
                        Activity        = 'Running Atomic Tests'
                        Status          = 'Progress:'
                        PercentComplete = ($testCount / ($technique.atomic_tests).Count * 100)
                    }
                    Write-Progress @props

                    Write-Verbose -Message 'Determining manual tests'

                    if ($test.executor.name.Contains('manual')) {
                        Write-Verbose -Message 'Unable to run manual tests'
                        continue
                    }

                    $testId = "$AT-$testCount $($test.name)"
                    if ($ShowDetailsBrief) {
                        Write-KeyValue $testId
                        continue
                    }

                    if ($PromptForInputArgs) {
                        $InputArgs = Invoke-PromptForInputArgs $test.input_arguments
                    }

                    if ($ShowDetails) {
                        Show-Details $test $testCount $technique $InputArgs $PathToPayloads
                        continue
                    }

                    Write-Debug -Message 'Gathering final Atomic test command'


                    if ($CheckPrereqs) {
                        Write-KeyValue "CheckPrereq's for: " $testId
                        $failureReasons = Invoke-CheckPrereqs $test $isElevated $InputArgs $PathToPayloads $TimeoutSeconds $session
                        Write-PrereqResults $FailureReasons $testId
                    }
                    elseif ($GetPrereqs) {
                        Write-KeyValue "GetPrereq's for: " $testId
                        if ( $test.executor.elevation_required -and -not $isElevated) {
                            Write-Host -ForegroundColor Red "Elevation required but not provided"
                        }
                        if ($nul -eq $test.dependencies) { Write-KeyValue "No Preqs Defined"; continue }
                        foreach ($dep in $test.dependencies) {
                            $executor = Get-PrereqExecutor $test
                            $description = (Merge-InputArgs $dep.description $test $InputArgs $PathToPayloads).trim()
                            Write-KeyValue  "Attempting to satisfy prereq: " $description
                            $final_command_prereq = Merge-InputArgs $dep.prereq_command $test $InputArgs $PathToPayloads
                            if ($executor -ne "powershell") { $final_command_prereq = ($final_command_prereq.trim()).Replace("`n", " && ") }
                            $final_command_get_prereq = Merge-InputArgs $dep.get_prereq_command $test $InputArgs $PathToPayloads
                            $res = Invoke-ExecuteCommand $final_command_prereq $executor $TimeoutSeconds $session -Interactive:$true

                            if ($res -eq 0) {
                                Write-KeyValue "Prereq already met: " $description
                            }
                            else {
                                $res = Invoke-ExecuteCommand $final_command_get_prereq $executor $TimeoutSeconds $session -Interactive:$Interactive
                                $res = Invoke-ExecuteCommand $final_command_prereq $executor $TimeoutSeconds $session -Interactive:$true
                                if ($res -eq 0) {
                                    Write-KeyValue "Prereq successfully met: " $description
                                }
                                else {
                                    Write-Host -ForegroundColor Red "Failed to meet prereq: $description"
                                }
                            }
                        }
                    }
                    elseif ($Cleanup) {
                        Write-KeyValue "Executing cleanup for test: " $testId
                        $final_command = Merge-InputArgs $test.executor.cleanup_command $test $InputArgs $PathToPayloads
                        $res = Invoke-ExecuteCommand $final_command $test.executor.name $TimeoutSeconds $session -Interactive:$Interactive
                        Write-KeyValue "Done executing cleanup for test: " $testId
                    }
                    else {
                        Write-KeyValue "Executing test: " $testId
                        $startTime = get-date
                        $final_command = Merge-InputArgs $test.executor.command $test $InputArgs $PathToPayloads
                        $res = Invoke-ExecuteCommand $final_command $test.executor.name $TimeoutSeconds $session -Interactive:$Interactive
                        Write-ExecutionLog $startTime $AT $testCount $test.name $ExecutionLogPath $targetHostname $targetUser $test.auto_generated_guid
                        Write-KeyValue "Done executing test: " $testId
                    }
                    if ($session) {
                        write-output (Invoke-Command -Session $session -scriptblock { (Get-Content $($Using:tmpDir + "art-out.txt")) -replace '\x00', ''; (Get-Content $($Using:tmpDir + "art-err.txt")) -replace '\x00', ''; if(-not $KeepStdOutStdErrFiles) { Remove-Item $($Using:tmpDir + "art-out.txt"), $($Using:tmpDir + "art-err.txt") -Force -ErrorAction Ignore }})
                    }
                    elseif (-not $interactive) {
                        # It is possible to have a null $session BUT also have stdout and stderr captured from 
                        #   the executed command. IF so then write the output to the pipe and cleanup the files.
                        $stdoutFilename = $tmpDir + "art-out.txt"
                        if (Test-Path $stdoutFilename -PathType leaf) { 
                            Write-Output ((Get-Content $stdoutFilename) -replace '\x00', '')
                            if(-not $KeepStdOutStdErrFiles) {
                                Remove-Item $stdoutFilename
                            }
                        }
                        $stderrFilename = $tmpDir + "art-err.txt"
                        if (Test-Path $stderrFilename -PathType leaf) { 
                            Write-Output ((Get-Content $stderrFilename) -replace '\x00', '')
                            if(-not $KeepStdOutStdErrFiles) { 
                                Remove-Item $stderrFilename
                            }
                        }
                    }
                } # End of foreach Test in single Atomic Technique
            } # End of foreach Technique in Atomic Tests
        } # End of Invoke-AtomicTestSingle function

        if ($AtomicTechnique -eq "All") {
            function Invoke-AllTests() {
                $AllAtomicTests = New-Object System.Collections.ArrayList
                Get-ChildItem $PathToAtomicsFolder -Directory -Filter T* | ForEach-Object {
                    $currentTechnique = [System.IO.Path]::GetFileName($_.FullName)
                    if ( $currentTechnique -match "T[0-9]{4}.?([0-9]{3})?" ) { $AllAtomicTests.Add($currentTechnique) | Out-Null }
                }
                $AllAtomicTests.GetEnumerator() | Foreach-Object { Invoke-AtomicTestSingle $_ }
            }
        
            if ( ($Force -or $CheckPrereqs -or $ShowDetails -or $ShowDetailsBrief -or $GetPrereqs) -or $psCmdlet.ShouldContinue( 'Do you wish to execute all tests?',
                    "Highway to the danger zone, Executing All Atomic Tests!" ) ) {
                Invoke-AllTests
            }
        }
        else {
            Invoke-AtomicTestSingle $AtomicTechnique
        }

    } # End of PROCESS block
    END { } # Intentionally left blank and can be removed
}
