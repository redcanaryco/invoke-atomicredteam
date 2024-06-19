# Loop through all atomic yaml files to load into list of objects
function Loop($fileList, $atomicType) {
    $AllAtomicTests = New-Object System.Collections.ArrayList

    $fileList | ForEach-Object {
        $currentTechnique = [System.IO.Path]::GetFileNameWithoutExtension($_.FullName)
        if ( $currentTechnique -ne "index" ) {
            $technique = Get-AtomicTechnique -Path $_.FullName
            if ($technique) {
                $technique.atomic_tests | ForEach-Object -Process {
                    $test = New-Object -TypeName psobject
                    $test | Add-Member -MemberType NoteProperty -Name Order -Value $null
                    $test | Add-Member -MemberType NoteProperty -Name Technique -Value ($technique.attack_technique -join "|")
                    $test | Add-Member -MemberType NoteProperty -Name TestName -Value $_.name
                    $test | Add-Member -MemberType NoteProperty -Name auto_generated_guid -Value $_.auto_generated_guid
                    $test | Add-Member -MemberType NoteProperty -Name supported_platforms -Value ($_.supported_platforms -join "|")
                    $test | Add-Member -MemberType NoteProperty -Name TimeoutSeconds -Value 120
                    $test | Add-Member -MemberType NoteProperty -Name InputArgs -Value ""
                    $test | Add-Member -MemberType NoteProperty -Name AtomicsFolder -Value $atomicType
                    $test | Add-Member -MemberType NoteProperty -Name enabled -Value $false
                    $test | Add-Member -MemberType NoteProperty -Name notes -Value ""

                    # Added dummy variable to grab the index values returned by appending to an arraylist so they don't get written to the screen
                    $dummy = $AllAtomicTests.Add(($test))
                }
            }
        }
    }
    return $AllAtomicTests

}

function Get-NewSchedule() {
    if (Test-Path $artConfig.PathToPublicAtomicsFolder) {
        $publicAtomicFiles = Get-ChildItem $artConfig.PathToPublicAtomicsFolder -Recurse -Exclude Indexes -Filter T*.yaml -File
        $publicAtomics = Loop $publicAtomicFiles "Public"
    }
    else {
        Write-Host -ForegroundColor Yellow "Public Atomics Folder not Found $($artConfig.PathToPublicAtomicsFolder)"
    }
    if (Test-Path $artConfig.PathToPrivateAtomicsFolder) {
        $privateAtomicFiles = Get-ChildItem $artConfig.PathToPrivateAtomicsFolder -Recurse -Exclude Indexes -Filter T*.yaml  -File
        $privateAtomics = Loop $privateAtomicFiles "Private"
    }
    else {
        Write-Verbose "Private Atomics Folder not Found $($artConfig.PathToPrivateAtomicsFolder)"
    }
    $AllAtomicTests = New-Object System.Collections.ArrayList
    try { $AllAtomicTests.AddRange($publicAtomics) }catch {}
    try { $AllAtomicTests.AddRange($privateAtomics) }catch {}
    return $AllAtomicTests
}

function Get-ScheduleRefresh() {
    $AllAtomicTests = Get-NewSchedule
    $schedule = Get-Schedule $null $false # get schedule, including inactive (ie not filtered)

    # Creating new schedule object for updating changes in atomics
    $newSchedule = New-Object System.Collections.ArrayList

    # Check if any tests haven't been added to schedule and add them
    $update = $false
    foreach ($guid in $AllAtomicTests | Select-Object -ExpandProperty auto_generated_guid) {
        $fresh = $AllAtomicTests | Where-Object { $_.auto_generated_guid -eq $guid }
        $old = $schedule | Where-Object { $_.auto_generated_guid -eq $guid }

        if (!$old) {
            $update = $true
            $newSchedule += $fresh
        }

        # Updating schedule with changes
        else {
            if ($fresh -is [array]) {
                $fresh = $fresh[0]
                LogRunnerMsg "Duplicated auto_generated_guid found $($fresh.auto_generated_guid) with technique $($fresh.Technique).
                            `nCannot Continue Execution. System Exit"
                Write-Host -ForegroundColor Yellow "Duplicated auto_generated_guid found $($fresh.auto_generated_guid) with technique $($fresh.Technique).
                            `nCannot Continue Execution. System Exit"; Start-Sleep 10
                exit
            }
            $old.Technique = $fresh.Technique
            $old.TestName = $fresh.TestName
            $old.supported_platforms = $fresh.supported_platforms

            $update = $true
            $newSchedule += $old
        }

    }
    if ($update) {
        $newSchedule | Export-Csv $artConfig.scheduleFile
        LogRunnerMsg "Schedule has been updated with new tests."
    }
    return $newSchedule

}

function Get-Schedule($listOfAtomics, $filterByEnabled = $true, $testGuids = $null, $filterByPlatform = $true) {
    if ($listOfAtomics -or (Test-Path($artConfig.scheduleFile))) {
        if ($listOfAtomics) {
            $schedule = Import-Csv $listOfAtomics
        }
        else {
            $schedule = Import-Csv $artConfig.scheduleFile
        }

        # Filter schedule to either Active/Supported Platform or TestGuids List
        if ($TestGuids) {
            $schedule = $schedule | Where-Object {
                ($Null -ne $TestGuids -and $TestGuids -contains $_.auto_generated_guid)
            }
        }
        else {
            if ($filterByEnabled -and $filterByPlatform) {
                $schedule = $schedule | Where-Object { ($_.enabled -eq $true -and ($_.supported_platforms -like "*" + $artConfig.OS + "*" )) }
            }
            elseif ($filterByEnabled) {
                $schedule = $schedule | Where-Object { $_.enabled -eq $true }
            }
            elseif ($filterByPlatform) {
                $schedule = $schedule | Where-Object { $_.supported_platforms -like "*" + $artConfig.OS + "*" }
            }
        }

    }
    else {
        Write-Host -ForegroundColor Yellow "Couldn't find schedule file ($($artConfig.scheduleFile)) Update the path to the schedule file in the config or generate a new one with 'Invoke-GenerateNewSchedule'"
    }

    if (($null -eq $schedule) -or ($schedule.length -eq 0)) { Write-Host -ForegroundColor Yellow "No active tests were found. Edit the 'enabled' column of your schedule file and set some to enabled (True)"; return $null }
    return $schedule
}

function Invoke-GenerateNewSchedule() {
    #create AtomicRunner-Logs directories if they don't exist
    New-Item -ItemType Directory $artConfig.atomicLogsPath -ErrorAction Ignore | Out-Null
    New-Item -ItemType Directory $artConfig.runnerFolder -ErrorAction Ignore | Out-Null

    LogRunnerMsg "Generating new schedule: $($artConfig.scheduleFile)"
    $schedule = Get-NewSchedule
    $schedule | Export-Csv $artConfig.scheduleFile -NoTypeInformation
    Write-Host -ForegroundColor Green "Schedule written to $($artConfig.scheduleFile)"
}

function Invoke-RefreshExistingSchedule() {
    LogRunnerMsg "Refreshing existing schedule: $($artConfig.scheduleFile)"
    $schedule = Get-ScheduleRefresh
    $schedule | Export-Csv $artConfig.scheduleFile -NoTypeInformation
    Write-Host -ForegroundColor Green "Refreshed schedule written to $($artConfig.scheduleFile)"
}
