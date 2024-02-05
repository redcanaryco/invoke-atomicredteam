# The Invoke-Process function is loosely based on code from https://github.com/guitarrapc/PowerShellUtil/blob/master/Invoke-Process/Invoke-Process.ps1
function Invoke-Process {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$FileName = "PowerShell.exe",

        [Parameter(Mandatory = $false, Position = 1)]
        [string[]]$Arguments = "",

        [Parameter(Mandatory = $false, Position = 3)]
        [Int]$TimeoutSeconds = 120,

        [Parameter(Mandatory = $false, Position = 4)]
        [String]$stdoutFile = $null,

        [Parameter(Mandatory = $false, Position = 5)]
        [String]$stderrFile = $null
    )

    end {
        $WorkingDirectory = if ($IsLinux -or $IsMacOS) { "/tmp" } else { $env:TEMP }
        try {
            # new Process
            if ($stdoutFile) {
                # new Process
                $process = NewProcess -FileName $FileName -Arguments $Arguments -WorkingDirectory $WorkingDirectory

                # Event Handler for Output
                $stdSb = New-Object -TypeName System.Text.StringBuilder
                $errorSb = New-Object -TypeName System.Text.StringBuilder
                $scripBlock =
                {
                    $x = $Event.SourceEventArgs.Data
                    if (-not [String]::IsNullOrEmpty($x)) {
                        $Event.MessageData.AppendLine($x)
                    }
                }
                $stdEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $scripBlock -MessageData $stdSb
                $errorEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $scripBlock -MessageData $errorSb

                # execution
                $process.Start() > $null
                $process.BeginOutputReadLine()
                $process.BeginErrorReadLine()
                # wait for complete
                $Timeout = [System.TimeSpan]::FromSeconds(($TimeoutSeconds))
                $isTimeout = $false
                if (-not $Process.WaitForExit($Timeout.TotalMilliseconds)) {
                    $isTimeout = $true
                    Invoke-KillProcessTree $process.id
                    Write-Host -ForegroundColor Red "Process Timed out after $TimeoutSeconds seconds, use '-TimeoutSeconds' to specify a different timeout"
                }
                $process.CancelOutputRead()
                $process.CancelErrorRead()

                # Unregister Event to recieve Asynchronous Event output (should be called before process.Dispose())
                Unregister-Event -SourceIdentifier $stdEvent.Name
                Unregister-Event -SourceIdentifier $errorEvent.Name

                $stdOutString = $stdSb.ToString().Trim()
                if ($stdOutString.Length -gt 0) {
                    Write-Host $stdOutString
                }

                $stdErrString = $errorSb.ToString().Trim()
                if ($stdErrString.Length -gt 0) {
                    Write-Host $stdErrString
                }

                # Get Process result
                return GetCommandResult -Process $process -StandardStringBuilder $stdSb -ErrorStringBuilder $errorSb -IsTimeOut $isTimeout
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
                    if ($stdoutFile) {
                        # Add a warning in stdoutFile in case of timeout
                        # problem: $stdoutFile was locked in writing by the process we just killed, sometimes it's too fast and the lock isn't released immediately
                        # solution: retry at most 10 times with 100ms between each attempt
                        For ($i = 0; $i -lt 10; $i++) {
                            try {
                                "<timeout>" | Out-File (Join-Path $WorkingDirectory $stdoutFile) -Append -Encoding ASCII
                                break # if we're here it means the file wasn't locked and Out-File worked, so we can leave the retry loop
                            }
                            catch {} # file is locked
                            Start-Sleep -m 100
                        }
                    }
                }

                if ($IsLinux -or $IsMacOS) {
                    Start-Sleep -Seconds 5 # On nix, the last 4 lines of stdout get overwritten upon return so pause for a bit to ensure user can view results
                }

                # Get Process result
                return [PSCustomObject]@{
                    StandardOutput = ""
                    ErrorOutput    = ""
                    ExitCode       = $process.ExitCode
                    ProcessId      = $Process.Id
                    IsTimeOut      = $IsTimeout
                }

            }

        }
        finally {
            if ($null -ne $process) { $process.Dispose() }
            if ($null -ne $stdEvent) { $stdEvent.StopJob(); $stdEvent.Dispose() }
            if ($null -ne $errorEvent) { $errorEvent.StopJob(); $errorEvent.Dispose() }
        }
    }

    begin {
        function NewProcess {
            [OutputType([System.Diagnostics.Process])]
            [CmdletBinding()]
            param
            (
                [parameter(Mandatory = $true)]
                [string]$FileName,

                [parameter(Mandatory = $false)]
                [string[]]$Arguments,

                [parameter(Mandatory = $false)]
                [string]$WorkingDirectory
            )

            # ProcessStartInfo
            $psi = New-object System.Diagnostics.ProcessStartInfo
            $psi.CreateNoWindow = $true
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.FileName = $FileName
            $psi.Arguments += $Arguments
            $psi.WorkingDirectory = $WorkingDirectory

            # Set Process
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            $process.EnableRaisingEvents = $true
            return $process
        }

        function GetCommandResult {
            [OutputType([PSCustomObject])]
            [CmdletBinding()]
            param
            (
                [parameter(Mandatory = $true)]
                [System.Diagnostics.Process]$Process,

                [parameter(Mandatory = $true)]
                [System.Text.StringBuilder]$StandardStringBuilder,

                [parameter(Mandatory = $true)]
                [System.Text.StringBuilder]$ErrorStringBuilder,

                [parameter(Mandatory = $true)]
                [Bool]$IsTimeout
            )

            return [PSCustomObject]@{
                StandardOutput = $StandardStringBuilder.ToString().Trim()
                ErrorOutput    = $ErrorStringBuilder.ToString().Trim()
                ExitCode       = $Process.ExitCode
                ProcessId      = $Process.Id
                IsTimeOut      = $IsTimeout
            }
        }
    }
}
