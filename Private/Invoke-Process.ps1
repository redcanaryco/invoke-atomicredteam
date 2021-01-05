# The Invoke-Process function is loosely based on code from https://github.com/guitarrapc/PowerShellUtil/blob/master/Invoke-Process/Invoke-Process.ps1
function Invoke-Process {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$FileName = "PowerShell.exe",

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Arguments = "",
        
        [Parameter(Mandatory = $false, Position = 3)]
        [Int]$TimeoutSeconds = 120,

        [Parameter(Mandatory = $false, Position =4)]
        [String]$stdoutFile = $null,

        [Parameter(Mandatory = $false, Position =5)]
        [String]$stderrFile = $null
    )

    end {
        $WorkingDirectory = if ($IsLinux -or $IsMacOS) { "/tmp" } else { $env:TEMP }
        try {
            # new Process
            if ($stdoutFile) {
                $process = Start-Process -FilePath $FileName -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $WorkingDirectory $stdoutFile) -RedirectStandardError (Join-Path $WorkingDirectory $stderrFile)
             }
            else {
                $process = Start-Process -FilePath $FileName -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru
            }
            $handle = $process.Handle # cache process.Handle, otherwise ExitCode is null from powershell processes

            # wait for complete
            $Timeout = [System.TimeSpan]::FromSeconds(($TimeoutSeconds))
            if (-not $process.WaitForExit($Timeout.TotalMilliseconds)) {
                Invoke-KillProcessTree $process.id

                Write-Host -ForegroundColor Red "Process Timed out after $TimeoutSeconds seconds, use '-TimeoutSeconds' to specify a different timeout"
                if ($stdoutFile) {
                    # Add a warning in stdoutFile in case of timeout
                    # problem: $stdoutFile was locked in writing by the process we just killed, sometimes it's too fast and the lock isn't released immediately
                    # solution: retry at most 10 times with 100ms between each attempt
                    For($i=0;$i -lt 10;$i++) { 
                        try {
                            "<timeout>" | Out-File (Join-Path $WorkingDirectory $stdoutFile) -Append -Encoding ASCII
                            break # if we're here it means the file wasn't locked and Out-File worked, so we can leave the retry loop
                        } catch {} # file is locked
                        Start-Sleep -m 100
                    }
                }
            }

            if ($IsLinux -or $IsMacOS) {
                Start-Sleep -Seconds 5 # On nix, the last 4 lines of stdout get overwritten upon return so pause for a bit to ensure user can view results
            }
            
            # Get Process result 
            return $process.ExitCode
        }
        finally {
            if ($null -ne $process) { $process.Dispose() }
        }
    }
}
