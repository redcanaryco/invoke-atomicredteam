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
            Write-Host -ForegroundColor Cyan "Writing output to $stdOutFile"
            # new Process
            if ($stdoutFile) {
                $process = Start-Process -FilePath $FileName -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
                # cache process.Handle, otherwise ExitCode is null from powershell processes
                $handle = $process.Handle
                # wait for complete
                $Timeout = [System.TimeSpan]::FromSeconds(($TimeoutSeconds))
                $isTimeout = $false
                if (-not $Process.WaitForExit($Timeout.TotalMilliseconds))
                {
                    $isTimeout = $true
                    Invoke-KillProcessTree $process.id
                    Write-Host -ForegroundColor Red "Process Timed out after $TimeoutSeconds seconds, use '-TimeoutSeconds' to specify a different timeout"
                } else {
                    $process.WaitForExit()
                }
                
                $stdOutString = Get-Content -Path $stdoutFile -Raw
                
                $stdErrString = Get-Content -Path $stderrFile -Raw
                
                if($stdOutString.Length -gt 0) {
                    Write-Host $stdOutString
                }

                if($stdErrString.Length -gt 0) {
                    Write-Host $stdErrString
                }

                return [PSCustomObject]@{
                    StandardOutput = $stdOutString
                    ErrorOutput = $stdErrString
                    ExitCode = $process.ExitCode
                    IsTimeOut = $isTimeout
                }

            }
            else {
                # This is the enitrety of the "old style" code, kept for interactive tests
                $process = Start-Process -FilePath $FileName -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru
                # cache process.Handle, otherwise ExitCode is null from powershell processes
                $handle = $process.Handle

                # wait for complete
                $Timeout = [System.TimeSpan]::FromSeconds(($TimeoutSeconds))
                if (-not $process.WaitForExit($Timeout.TotalMilliseconds)) {
                    Invoke-KillProcessTree $process.id
                    Write-Host -ForegroundColor Red "Process Timed out after $TimeoutSeconds seconds, use '-TimeoutSeconds' to specify a different timeout"
                }

                if ($IsLinux -or $IsMacOS) {
                    Start-Sleep -Seconds 5 # On nix, the last 4 lines of stdout get overwritten upon return so pause for a bit to ensure user can view results
                }
                
                # Get Process result
                return [PSCustomObject]@{
                    StandardOutput = ""
                    ErrorOutput = ""
                    ExitCode = $process.ExitCode
                    IsTimeOut = $IsTimeout
                }

            }
            
        }
        finally {
            if ($null -ne $process) { $process.Dispose() }
            if ($null -ne $stdEvent){ $stdEvent.StopJob(); $stdEvent.Dispose() }
            if ($null -ne $errorEvent){ $errorEvent.StopJob(); $errorEvent.Dispose() }
        }
    }

}
