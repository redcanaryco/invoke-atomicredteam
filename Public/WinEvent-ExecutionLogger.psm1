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
    if ($isWindows -and -not [System.Diagnostics.EventLog]::Exists('Atomic Red Team')) {
        New-EventLog -Source "Applications and Services Logs" -LogName "Atomic Red Team"
    }
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

    Write-EventLog  -Source "Applications and Services Logs" -LogName "Atomic Red Team" -EventID 3001 -EntryType Information -Message $msg -Category 1 -RawData 10, 20
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
