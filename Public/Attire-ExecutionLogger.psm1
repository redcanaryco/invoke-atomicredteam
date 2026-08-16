# Attire-ExecutionLogger.psm1
# Copyright 2023 Security Risk Advisors

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

$script:attireLog = [PSCustomObject]@{
    'attire-version' = '1.1'
    'execution-data' = ''
    'procedures'     = @()
}

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

    $ipAddress = Get-PreferredIPAddress $isWindowsFlag

    if ($targetUser -isnot [string]) {
        if ([bool]($targetUser.PSobject.Properties.name -match "^value$")) {
            $targetUser = $targetUser.value
        }
        else {
            $targetUser = $targetUser.ToString()
        }
    }
    if ($targetHostname -isnot [string]) {
        if ([bool]($targetHostname.PSobject.Properties.name -match "^value$")) {
            $targetHostname = $targetHostname.value
        }
        else {
            $targetHostname = $targetHostname.ToString()
        }
    }

    $target = [PSCustomObject]@{
        user = $targetUser
        host = $targetHostname
        ip   = $ipAddress
        path = $Env:PATH
    }

    $guid = New-Guid
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($guid.Guid)
    $executionId = [Convert]::ToBase64String($bytes)

    $executionCategory = [PSCustomObject]@{
        'name'         = "Atomic Red Team"
        'abbreviation' = "ART"
    }

    $executionData = [PSCustomObject]@{
        'execution-source'   = "Invoke-Atomicredteam"
        'execution-id'       = $executionId
        'execution-category' = $executionCategory
        'execution-command'  = $commandLine
        target               = $target
        'time-generated'     = ""
    }

    $script:attireLog.'execution-data' = $executionData
}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $res, $isWindowsFlag) {

    $startTime = (Get-Date($startTime).ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z').ToString()
    $stopTime = (Get-Date($stopTime).ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z').ToString()

    $procedureId = [PSCustomObject]@{
        type = "guid"
        id   = $testGuid
    }

    $step = [PSCustomObject]@{
        'order'      = 1
        'time-start' = $startTime
        'time-stop'  = $stopTime
        'executor'   = $testExecutor
        'command'    = $command
        'process-id' = $res.ProcessId
        'exit-code'  = $res.ExitCode
        'is-timeout' = $res.IsTimeout
        'output'     = @()
    }

    $stdOutContents = $res.StandardOutput
    if (($stdOutContents -isnot [string]) -and ($null -ne $stdOutContents)) {
        $stdOutContents = $stdOutContents.ToString()
    }

    $outputStdConsole = [PSCustomObject]@{
        content = $stdOutContents
        level   = "STDOUT"
        type    = "console"
    }

    $stdErrContents = $res.ErrorOutput
    if (($stdErrContents -isnot [string]) -and ($null -ne $stdErrContents)) {
        $stdErrContents = $stdErrContents.ToString()
    }

    $outputErrConsole = [PSCustomObject]@{
        content = $stdErrContents
        level   = "STDERR"
        type    = "console"
    }

    [bool] $foundOutput = $false
    if ($res.StandardOutput.length -gt 0) {
        $foundOutput = $true
        $step.output += $outputStdConsole
    }

    if ($res.ErrorOutput.length -gt 0) {
        $foundOutput = $true
        $step.output += $outputErrConsole
    }

    if (!$foundOutput) {
        $emptyOutput = [PSCustomObject]@{
            content = ""
            level   = "STDOUT"
            type    = "console"
        }
        $step.output += $emptyOutput
    }

    $procedure = [PSCustomObject]@{
        'mitre-technique-id'    = $technique
        'procedure-name'        = $testName
        'procedure-id'          = $procedureId
        'procedure-description' = $testDescription
        order                   = $testNum
        steps                   = @()
    }

    $procedure.steps += $step

    $script:attireLog.procedures += $procedure
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

    $script:attireLog.'execution-data'.'time-generated' = (Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')
    #$script:attireLog | Export-Csv -Path "attireLogObject.csv"
    $content = ($script:attireLog | ConvertTo-Json -Depth 12)
    #$Utf8NoBom = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines((Resolve-NonexistantPath($logPath)), $content)
    #Out-File -FilePath $logPath -InputObject ($script:attireLog | ConvertTo-Json -Depth 12) -Append -Encoding ASCII
    $script:attireLog = [PSCustomObject]@{
        'attire-version' = '1.1'
        'execution-data' = ''
        procedures       = @()
    }
}

function Resolve-NonexistantPath($File) {
    # Use a non-automatic error variable name to avoid clobbering the global $Error automatic variable
    $Path = Resolve-Path $File -ErrorAction SilentlyContinue -ErrorVariable resolveError

    if (-not($Path) -and $resolveError) {
        $Path = $resolveError[0].TargetObject
    }

    return $Path
}
