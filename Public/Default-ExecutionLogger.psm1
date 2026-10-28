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
    if (!(Test-Path $logPath)) {
        New-Item $logPath -Force -ItemType File | Out-Null
    }
    $ipAddress = Get-PreferredIPAddress $isWindowsFlag
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
