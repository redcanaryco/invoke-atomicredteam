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
                # new Process
                $process = NewProcess -FileName $FileName -Arguments $Arguments -WorkingDirectory $WorkingDirectory
                
                # execution
                $process.Start() > $null
                $StdIn = $process.StandardInput
                $StdIn.Close()
                # wait for complete
                $Timeout = [System.TimeSpan]::FromSeconds(($TimeoutSeconds))
                $isTimeout = $false
                $return = $Process.WaitForExit($Timeout.TotalMilliseconds)
                if (-not $return)
                {
                    $isTimeout = $true
                    Invoke-KillProcessTree $process.id
                    Write-Host -ForegroundColor Red "Process Timed out after $TimeoutSeconds seconds, use '-TimeoutSeconds' to specify a different timeout"
                }
                $stdOutString = $process.StandardOutput.ReadToEndAsync().Result.Trim();
                $stdErrString = $process.StandardError.ReadToEndAsync().Result.Trim();

                if($stdOutString.Length -gt 0) {
                    Write-Host $stdOutString
                }
                
                if($stdErrString.Length -gt 0) {
                    Write-Host $stdErrString
                }

                # Get Process result
                return GetCommandResult -Process $process -StandardString $stdOutString -ErrorString $stdErrString -IsTimeOut $isTimeout
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

    begin
    {
        function NewProcess
        {
            [OutputType([System.Diagnostics.Process])]
            [CmdletBinding()]
            param
            (
                [parameter(Mandatory = $true)]
                [string]$FileName,
                
                [parameter(Mandatory = $false)]
                [string]$Arguments,
                
                [parameter(Mandatory = $false)]
                [string]$WorkingDirectory
            )

            # ProcessStartInfo
            $psi = New-object System.Diagnostics.ProcessStartInfo 
            $psi.CreateNoWindow = $true
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.RedirectStandardInput = $true
            $psi.FileName = $FileName
            $psi.Arguments+= $Arguments
            $psi.WorkingDirectory = $WorkingDirectory

            # Set Process
            $process = New-Object System.Diagnostics.Process 
            $process.StartInfo = $psi
            $process.EnableRaisingEvents = $true
            return $process
        }

        function GetCommandResult
        {
            [OutputType([PSCustomObject])]
            [CmdletBinding()]
            param
            (
                [parameter(Mandatory = $true)]
                [System.Diagnostics.Process]$Process,

                [parameter(Mandatory = $true)]
                [AllowEmptyString()]
                [System.String]$StandardString,

                [parameter(Mandatory = $true)]
                [AllowEmptyString()]
                [System.String]$ErrorString,

                [parameter(Mandatory = $true)]
                [Bool]$IsTimeout
            )
            
            return [PSCustomObject]@{
                StandardOutput = $StandardString
                ErrorOutput = $ErrorString
                ExitCode = $Process.ExitCode
                IsTimeOut = $IsTimeout
            }
        }
    }
}
