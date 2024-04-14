function Set-Sudo ($set_sudo) {

    $ErrorActionPreference = "Stop"
    $env:SUDO_ASKPASS="/bin/false"

    try {
        if ((sudo -A whoami) -and ((sudo grep -r $env:USER /etc/sudoers | grep NOPASSWD:ALL) -or (sudo grep -r $env:USER /etc/sudoers.d | grep NOPASSWD:ALL))){

            if($set_sudo){
                Write-Host "Passwordless logon already configured.`n"
            }
            $nopassword_enabled = $true

        }
        elseif ($set_sudo -eq $true){

            Write-Host "Configuring Passwordless logon...`n"
            Write-Output "$env:USER ALL=(ALL) NOPASSWD:ALL" > /tmp/90-$env:USER-sudo-access
            sudo install -m 440 /tmp/90-$env:USER-sudo-access /etc/sudoers.d/90-$env:USER-sudo-access
            rm -f /tmp/90-$env:USER-sudo-access
            $nopassword_enabled = $true
        }
        else {
            write-host "Host not configured for passwordless logon"
            $nopassword_enabled = $false
        }
    }
    catch {
        write-host "Error configuring passwordless logon"
        $nopassword_enabled = $false
    }
return $nopassword_enabled
}
