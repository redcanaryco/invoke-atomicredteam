function Start-ExecutionLog {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)][object]$startTime,
        [string]$logPath,
        [string]$targetHostname,
        [string]$targetUser,
        [string]$commandLine,
        [bool]$isWindowsFlag
    )

    if (-not $PSCmdlet.ShouldProcess($logPath, 'Start execution log')) { return }

    # Mark parameters as used to satisfy static analysis
    $null = $startTime; $null = $logPath; $null = $targetHostname; $null = $targetUser; $null = $commandLine; $null = $isWindowsFlag

}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $res, $isWindowsFlag) {
    $timeUTC = (Get-Date($startTime).toUniversalTime() -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $timeLocal = (Get-Date($startTime) -uformat "%Y-%m-%dT%H:%M:%SZ").ToString()
    $ipAddress = Get-PreferredIPAddress $isWindowsFlag

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
        $jsonMsg = $msg | ConvertTo-Json -Compress
        Send-SyslogMessage -Server $artConfig.syslogServer -Port $artConfig.syslogPort -Message $jsonMsg -Severity "Informational" -Facility "daemon" -Transport $artConfig.syslogProtocol
    }
}

function Stop-ExecutionLog {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [Parameter(Mandatory=$true)][object]$startTime,
        [string]$logPath,
        [string]$targetHostname,
        [string]$targetUser,
        [bool]$isWindowsFlag
    )

    if (-not $PSCmdlet.ShouldProcess($logPath, 'Stop execution log')) { return }

    # Mark parameters as used to satisfy static analysis
    $null = $startTime; $null = $logPath; $null = $targetHostname; $null = $targetUser; $null = $isWindowsFlag

}
