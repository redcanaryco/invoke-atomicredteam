function Start-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $commandLine, $isWindows) {
    if ($isWindows -and -not [System.Diagnostics.EventLog]::Exists('Atomic Red Team')) {
        New-EventLog -Source "Applications and Services Logs" -LogName "Atomic Red Team"
    }
}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $res, $isWindows) {
    $timeUTC = (Get-Date($startTime).toUniversalTime() -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $timeLocal = (Get-Date($startTime) -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $ipAddress = Get-PreferredIPAddress $isWindows

    $msg = [PSCustomObject][ordered]@{
        "Execution Time (UTC)"   = $timeUTC
        "Execution Time (Local)" = $timeLocal
        "Technique"              = $technique
        "Test Number"            = $testNum
        "Test Name"              = $testName
        "Hostname"               = $targetHostname
        "IP Address"             = $ipAddress
        "Username"               = $targetUser
        "GUID"                   = $testGuid
        "Tag"                    = "atomicrunner"
        "CustomTag"              = $artConfig.CustomTag
        "ProcessId"              = $res.ProcessId
        "ExitCode"               = $res.ExitCode
    }

    Write-EventLog  -Source "Applications and Services Logs" -LogName "Atomic Red Team" -EventID 3001 -EntryType Information -Message $msg -Category 1 -RawData 10, 20
}

function Stop-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $isWindows) {

}
