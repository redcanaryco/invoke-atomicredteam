function Invoke-ExecuteCommand ($finalCommand, $executor, $TimeoutSeconds, $session = $null) {
    $null = @( 
        if ($null -eq $finalCommand) { return 0 }
        $finalCommand = $finalCommand.trim()
        Write-Verbose -Message 'Invoking Atomic Tests using defined executor'
        if ($executor -eq "command_prompt" -or $executor -eq "sh" -or $executor -eq "bash") {
            $execCommand = $finalCommand.Replace("`n", " & ")
            $execPrefix = "-c"
            $execExe = $executor
            if ($executor -eq "command_prompt") { $execPrefix = "/c"; $execExe = "cmd.exe" }
            $arguments = "$execPrefix `"$execCommand`"" 
        }
        elseif ($executor -eq "powershell") {
            $execCommand = $finalCommand -replace "`"", "`\`"`""
            $execExe = "powershell.exe"; if ($IsLinux -or $IsMacOS) { $execExe = "pwsh" }
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
            $res = invoke-command -Session $session -ScriptBlock { Invoke-Process -filename $Using:execExe -Arguments $Using:arguments -TimeoutSeconds $Using:TimeoutSeconds -stdoutFile $env:temp\art-out.txt -stderrFile $env:temp\art-err.txt  }
        }
        else {
            $res = Invoke-Process -filename $execExe -Arguments $arguments -TimeoutSeconds $TimeoutSeconds  
        }              

    )
    $res
}