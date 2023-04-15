function Invoke-KickoffAtomicRunner {

    #log rotation function
    function Rotate-Log {
        Param ($log, $max_filesize, $max_age)
        $datetime = Get-Date -uformat "%Y-%m-%d-%H%M"

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

    #Check if logfiles exist. If not create them.
    $all_log_file = Join-Path $artConfig.atomicLogsPath "all-out-$($artConfig.basehostname).txt"
    if ($False -eq (Test-Path $all_log_file)) {
        New-Item $all_log_file -ItemType File -Force
    }
    if ($False -eq (Test-Path $artConfig.logFile)) {
        New-Item $artConfig.logFile -ItemType File -Force
    }


    #Rotate logs based on FileSize and Date max_filesize
    $max_filesize = 200 #in MB
    $max_file_age = 30 #in days
    $log = get-item $all_log_file
    Rotate-Log $log $max_filesize $max_file_age
    $log = get-item $artConfig.logFile
    Rotate-Log $log $max_filesize $max_file_age #no need to repeat this. Can reduce further.

    # Optional additional delay before starting
    Start-Sleep $artConfig.kickOffDelay.TotalSeconds

    # Invoke the Runner Script
    if ($artConfig.debug) {
        Invoke-AtomicRunner *>> $all_log_file
    }
    else {
        Invoke-AtomicRunner
    }
}

function LogRunnerMsg ($message) {
    $now = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Write-Host -fore cyan $message
    Add-Content $artConfig.logFile "$now`: $message"
}