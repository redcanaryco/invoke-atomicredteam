function Start-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $commandLine, $isWindows) {

}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $stdOut, $stdErr, $isWindows) {
    if (!(Test-Path $logPath)) { 
        New-Item $logPath -Force -ItemType File | Out-Null
    } 

    $timeUTC = (Get-Date($startTime).toUniversalTime() -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $timeLocal = (Get-Date($startTime) -uformat "%Y-%m-%dT%H:%M:%S").ToString()
    $msg = [PSCustomObject][ordered]@{ 
        "Execution Time (UTC)"   = $timeUTC;
        "Execution Time (Local)" = $timeLocal; 
        "Technique"              = $technique; 
        "Test Number"            = $testNum; 
        "Test Name"              = $testName; 
        "Hostname"               = $targetHostname; 
        "Username"               = $targetUser
        "GUID"                   = $testGuid
    } 
    
    $msg | Export-Csv -Path $LogPath -NoTypeInformation -Append

    # send syslog message if a syslog server is defined in Public/config.ps1
    if([bool]$syslogServer -and [bool]$syslogPort){
        $UDPClient = New-Object System.Net.Sockets.UdpClient
        $msg | Add-Member -Name "Tag" -Type NoteProperty -Value "atomicrunner"
        $encodedSyslogMessage = [System.Text.Encoding]::UTF8.GetBytes(($msg | ConvertTo-Json))
        $UDPClient.Connect($syslogServer,$syslogPort)
        $null = $UDPClient.Send($encodedSyslogMessage, $encodedSyslogMessage.Length)
    }
}

function Stop-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $isWindows) {

}