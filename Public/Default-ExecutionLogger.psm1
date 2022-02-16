function Start-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $commandLine, $isWindows) {

}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $stdOut, $stdErr, $isWindows) {
    if (!(Test-Path $logPath)) { 
        New-Item $logPath -Force -ItemType File | Out-Null
    } 

    $timeUTC = (Get-Date($startTime).toUniversalTime() -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $timeLocal = (Get-Date($startTime) -uformat "%Y-%m-%dT%H:%M:%S").ToString()
    [PSCustomObject][ordered]@{ 
        "Execution Time (UTC)"   = $timeUTC;
        "Execution Time (Local)" = $timeLocal; 
        "Technique"              = $technique; 
        "Test Number"            = $testNum; 
        "Test Name"              = $testName; 
        "Hostname"               = $targetHostname; 
        "Username"               = $targetUser
        "GUID"                   = $testGuid
    } | Export-Csv -Path $LogPath -NoTypeInformation -Append
}

function Stop-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $isWindows) {

}