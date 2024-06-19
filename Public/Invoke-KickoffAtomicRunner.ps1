function Invoke-KickoffAtomicRunner {

    #log rotation function
    function Rotate-Log {
        Param ($logPath, $max_filesize, $max_age)
        $datetime = Get-Date -uformat "%Y-%m-%d-%H%M"

        $log = Get-Item $logPath
        if ($log.Length / 1MB -ge $max_filesize) {
            Write-Host "file named $($log.name) is bigger than $max_filesize MB"
            $newname = "$($log.Name)_${datetime}.arclog"
            Rename-Item $log.PSPath $newname
            Write-Host "Done rotating file"
        }

        $logdir_content = Get-ChildItem $artConfig.atomicLogsPath -filter "*.arclog"
        $cutoff_date = (get-date).AddDays($max_age)
        $logdir_content | ForEach-Object {
            if ($_.LastWriteTime -gt $cutoff_date) {
                Remove-Item $_
                Write-Host "Removed $($_.PSPath)"
            }
        }
    }

    #Create log files as needed
    $all_log_file = Join-Path $artConfig.atomicLogsPath "all-out-$($artConfig.basehostname).txt"
    $all_log_file_cleanup = Join-Path $artConfig.atomicLogsPath "all-out-$($artConfig.basehostname)-cleanup.txt"
    New-Item $all_log_file -ItemType file -ErrorAction Ignore
    New-Item $all_log_file_cleanup -ItemType file -ErrorAction Ignore
    New-Item $artConfig.logFile -ItemType File -ErrorAction Ignore

    #Rotate logs based on FileSize and Date max_filesize
    $max_filesize = 200 #in MB
    $max_file_age = 30 #in days
    Rotate-Log $all_log_file $max_filesize $max_file_age
    Rotate-Log $all_log_file_cleanup $max_filesize $max_file_age

    Rotate-Log $artConfig.logFile $max_filesize $max_file_age #no need to repeat this. Can reduce further.

    # Optional additional delay before starting
    Start-Sleep $artConfig.kickOffDelay.TotalSeconds

    $WorkingDirectory = if ($IsLinux -or $IsMacOS) { "/tmp" } else { $env:TEMP }
    $FileName = if ($IsLinux -or $IsMacOS) { "pwsh" } else { "powershell.exe" }
    if ($artConfig.debug) { $Arguments = "-Command Invoke-AtomicRunner *>> $all_log_file" } else { $Arguments = "-Command Invoke-AtomicRunner" }
    # Invoke the atomic as its own process because we don't want to skip the cleanup and rename process in the event that AV kills the process running the atomic
    $p1 = Start-Process -FilePath $FileName -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -PassThru

    if ($artConfig.debug) { $Arguments = "-Command Invoke-AtomicRunner -scheduledTaskCleanup *>> $all_log_file_cleanup" } else { $Arguments = "-Command Invoke-AtomicRunner -scheduledTaskCleanup" }
    $p2 = Start-Process -FilePath $FileName -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -PassThru

    return $p1,$p2

}

function LogRunnerMsg ($message) {
    $mutexName = 'AtomicRunnerLoggingMutex'
    $mutex = New-Object 'Threading.Mutex' $false, $mutexName
    # Grab the mutex. Will block until this process has it.
    $mutex.WaitOne() | Out-Null
    try {
        # OK. Now it is safe to write to your log file
        $now = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
        Write-Host -fore cyan $message
        Add-Content $artConfig.logFile "$now`: $message"
    }
    finally {
        $mutex.ReleaseMutex()
    }
}