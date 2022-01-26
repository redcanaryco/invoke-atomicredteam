 $script:attireLog = [PSCustomObject]@{
    'attire-version'     = '1.1'
    'execution-data' = ''
    'procedures'    = @()
}

function Start-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser, $commandLine) {

    # Sometimes unwanted NoteProperties can end up in the log file.
    # Creating new variables with explicit casting is a workaround.
    $tu = [String] $targetUser
    $th = [String] $targetHostname

    $target = [PSCustomObject]@{
        user = $tu
        host = $th
        ip = (Get-NetIPAddress).IPAddress | Select-Object -first 1
        path = $Env:PATH
    }

    $guid = New-Guid
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($guid.Guid)
    $executionId = [Convert]::ToBase64String($bytes)

    $executionCategory = [PSCustomObject]@{
        'name' = "Atomic Red Team"
        'abbreviation' = "ART"
    }

    $executionData = [PSCustomObject]@{
        'execution-source' = "Invoke-Atomicredteam"
        'execution-id' = $executionId
        'execution-category' = $executionCategory
        'execution-command' = $commandLine
        target = $target
        'time-generated' = ""
    }

    $script:attireLog.'execution-data' = $executionData
}

function Write-ExecutionLog($startTime, $stopTime, $technique, $testNum, $testName, $testGuid, $testExecutor, $testDescription, $command, $logPath, $targetHostname, $targetUser, $stdOut, $stdErr) {

    $procedureId = [PSCustomObject]@{
        type = "guid"
        id = $testGuid
    }

    $step = [PSCustomObject]@{
        'order' = 1
        'time-start' = $startTime
        'time-stop' = $stopTime
        'executor' = $testExecutor
        'command' = $command
        'output' = @()
    }

    $outputStdConole = [PSCustomObject]@{
        content = $stdOut
        level = "STDOUT"
        type = "console"
    }

    $outputErrConole = [PSCustomObject]@{
        content = $stdErr
        level = "STDERR"
        type = "console"
    }

    if($stdOut.length -gt 0) {
        $step.output += $outputStdConole
    }

    if($stdErr.length -gt 0) {
        $step.output += $outputErrConole
    }

    $procedure = [PSCustomObject]@{
        'mitre-technique-id' = $technique
        'procedure-name' = $testName
        'procedure-id' = $procedureId
        'procedure-description' = $testDescription
        order = $testNum
        steps = @()
    }

    $procedure.steps += $step

    $script:attireLog.procedures += $procedure
}

function Stop-ExecutionLog($startTime, $logPath, $targetHostname, $targetUser) {
    $script:attireLog.'execution-data'.'time-generated' = (Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')
    $content = ($script:attireLog | ConvertTo-Json -Depth 12)
    [System.IO.File]::WriteAllLines((Resolve-NonexistentPath($logPath)), $content)
    $script:attireLog = [PSCustomObject]@{
        'attire-version'     = '1.1'
        'execution-data' = ''
        procedures    = @()
    }
}

function Resolve-NonexistentPath($File) {
    $Path = Resolve-Path $File -ErrorAction SilentlyContinue -ErrorVariable error

    if(-not($Path)) {
        $Path = $error[0].TargetObject
    }

    return $Path
}