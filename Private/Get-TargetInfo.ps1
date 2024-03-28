function Get-TargetInfo($Session) {
    $tmpDir = "$env:TEMP\"
    $isElevated = $false
    $targetHostname = hostname
    $targetUser = whoami
    if ($Session) {
        $targetPlatform, $isElevated, $tmpDir, $targetHostname, $targetUser = invoke-command -Session $Session -ScriptBlock {
            $targetPlatform = "windows"
            $tmpDir = "/tmp/"
            $targetHostname = hostname
            $targetUser = whoami
            if ($IsLinux) { $targetPlatform = "linux" }
            elseif ($IsMacOS) { $targetPlatform = "macos" }
            else {
                # windows
                $tmpDir = "$env:TEMP\"
                $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            }
            if ($IsLinux -or $IsMacOS) {
                $isElevated = $false
                $privid = id -u
                if ($privid -eq 0) { $isElevated = $true }
            }
            $targetPlatform, $isElevated, $tmpDir, $targetHostname, $targetUser
        } # end ScriptBlock for remote session
    }
    else {
        $targetPlatform = "linux"
        if ($IsLinux -or $IsMacOS) {
            $tmpDir = "/tmp/"
            $isElevated = $false
            $privid = id -u
            if ($privid -eq 0) { $isElevated = $true }
            if ($IsMacOS) { $targetPlatform = "macos" }
        }
        else {
            $targetPlatform = "windows"
            $isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }

    }
    $targetPlatform, $isElevated, $tmpDir, $targetHostname, $targetUser
}
