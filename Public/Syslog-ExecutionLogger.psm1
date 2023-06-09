function Start-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $commandLine, $isWindows) {

}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $res, $isWindows) {
    $timeUTC = (Get-Date($startTime).toUniversalTime() -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $timeLocal = (Get-Date($startTime) -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
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
    
    }
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
    
    # send syslog message if a syslog server is defined in Public/config.ps1
    if ([bool]$artConfig.syslogServer -and [bool]$artConfig.syslogPort) {
        $jsonMsg = $msg | ConvertTo-Json
        Send-SyslogMessage -Server $artConfig.syslogServer -Port $artConfig.syslogPort -Message $jsonMsg -Severity "Informational" -Facility "daemon"
    }
}

function Stop-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $isWindows) {

}
