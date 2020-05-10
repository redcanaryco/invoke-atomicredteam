function Write-ExecutionLog($startTime, $technique, $testNum, $testName, $logPath, $targetHostname, $targetUser, $guid) {
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
        "GUID"                   = $guid
    } | Export-Csv -Path $LogPath -NoTypeInformation -Append
}