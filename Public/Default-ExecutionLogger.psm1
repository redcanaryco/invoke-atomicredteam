function Start-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $commandLine, $isWindows) {

}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $res, $isWindows) {
    if (!(Test-Path $logPath)) { 
        New-Item $logPath -Force -ItemType File | Out-Null
    } 
    if ($isWindows){
        $ipAddress = (Get-NetIPAddress | Where-Object { $_.SuffixOrigin -ne "WellKnown"}).IPAddress
    }
    elseif ($IsMacOS) {
        $ipAddress = ifconfig -l | xargs -n1 ipconfig getifaddr
    } 
    elseif ($IsLinux) {
        $ipAddress = ip -4 -br addr show |sed -n -e 's/^.*UP\s* //p'
    }
    else {
        $ipAddress = ''
    }
    $timeUTC = (Get-Date($startTime).toUniversalTime() -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $timeLocal = (Get-Date($startTime) -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
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
        "ProcessId"              = $res.ProcessId
        "ExitCode"               = $res.ExitCode
    } 
    
    $msg | Export-Csv -Path $LogPath -NoTypeInformation -Append
}

function Stop-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $isWindows) {

}