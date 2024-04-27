function Invoke-CheckPrereqs ($test, $isElevated, $executionPlatform, $customInputArgs, $PathToAtomicsFolder, $TimeoutSeconds, $session = $null) {
    $FailureReasons = New-Object System.Collections.ArrayList
    if ( $test.executor.elevation_required -and -not $isElevated) {
        $FailureReasons.add("Elevation required but not provided`n") | Out-Null
    }
    foreach ($dep in $test.dependencies) {
        $executor = Get-PrereqExecutor $test
        $final_command = Merge-InputArgs $dep.prereq_command $test $customInputArgs $PathToAtomicsFolder
        if ($executor -ne "powershell") { $final_command = ($final_Command.trim()).Replace("`n", " && ") }
        $res = Invoke-ExecuteCommand $final_command $executor $executionPlatform $TimeoutSeconds  $session
        $description = Merge-InputArgs $dep.description $test $customInputArgs $PathToAtomicsFolder
        if ($res.ExitCode -ne 0) {
            $FailureReasons.add($description) | Out-Null
        }
    }
    $FailureReasons
}
