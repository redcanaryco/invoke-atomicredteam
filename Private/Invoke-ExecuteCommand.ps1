function Invoke-ExecuteCommand ($finalCommand, $executor, $TimeoutSeconds, $session = $null, $interactive) {
    $null = @(
        if ($null -eq $finalCommand) { return 0 }
        $finalCommand = $finalCommand.trim()
        Write-Verbose -Message 'Invoking Atomic Tests using defined executor'
        if ($executor -eq "command_prompt" -or $executor -eq "sh" -or $executor -eq "bash") {
            $execPrefix = "-c"
            $execExe = $executor
            # handle executor loosely (example: if sh specified but OS is windows, use command_prompt)
            if (($IsLinux -or $IsMacOS) -and ($executor -eq "command_prompt") ) { $executor = "sh" }
            if ( (-not ($IsLinux -or $IsMacOS))  -and ($executor -eq "sh" -or $executor -eq "bash") ) { $executor = "command_prompt"}
            if ($executor -eq "command_prompt") { 
                    $execPrefix = "/c"; 
                    $execExe = "cmd.exe"; 
                    $execCommand = $finalCommand -replace "`n", " & " 
            }
            else {
                    $finalCommand = $finalCommand -replace "[\\`"]", "`\$&"
                    $execCommand = $finalCommand -replace "(?<!;)\n", "; "
            }
            $arguments = "$execPrefix `"$execCommand`""
        }
        elseif ($executor -eq "powershell") {
            $execCommand = $finalCommand -replace "`"", "`\`"`""
            if ($session) {
                if ($targetPlatform -eq "windows") {
                        $execExe = "powershell.exe"
                }
                else {
                        $execExe = "pwsh"
                }
            }
            else {
                $execExe = "powershell.exe"; if ($IsLinux -or $IsMacOS) { $execExe = "pwsh" }
            }
            $arguments = "& {$execCommand}"
        }
        else {
            Write-Warning -Message "Unable to generate or execute the command line properly. Unknown executor"
            $res = -1
            return $res
        }
        if ($session) {
            $scriptParentPath = Split-Path $import -Parent
            $fp = Join-Path $scriptParentPath "Invoke-Process.ps1"
            $fp2 = Join-Path $scriptParentPath "Invoke-KillProcessTree.ps1"
            invoke-command -Session $session -FilePath $fp
            invoke-command -Session $session -FilePath $fp2
            $res = invoke-command -Session $session -ScriptBlock { Invoke-Process -filename $Using:execExe -Arguments $Using:arguments -TimeoutSeconds $Using:TimeoutSeconds -stdoutFile "art-out.txt" -stderrFile "art-err.txt"  }
        }
        else {
            if ($interactive) {
                # This use case is: Local execution of tests that contain interactive prompts
                #   In this situation, let the stdout/stderr flow to the console
                $res = Invoke-Process -filename $execExe -Arguments $arguments -TimeoutSeconds $TimeoutSeconds
            }
            else {
                # Local execution that DO NOT contain interactive prompts
                #   In this situation, capture the stdout/stderr for Invoke-AtomicTest to send to the caller
                $res = Invoke-Process -filename $execExe -Arguments $arguments -TimeoutSeconds $TimeoutSeconds -stdoutFile "art-out.txt" -stderrFile "art-err.txt" 
            }
        }
    )
    $res
}