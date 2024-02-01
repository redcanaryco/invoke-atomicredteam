function Set-Sudo {

    $ErrorActionPreference = "Stop"
    $env:SUDO_ASKPASS="/bin/false"

    try {
        if ((sudo -A whoami) -and ((sudo grep -r $env:USER /etc/sudoers | grep NOPASSWD:ALL) -or (sudo grep -r $env:USER /etc/sudoers.d | grep NOPASSWD:ALL))){
            
            Write-Host "Passwordless logon already configured.`n"

        }
        else{
            
            Write-Host "Configuring Passwordless logon...`n"
            echo "$env:USER ALL=(ALL) NOPASSWD:ALL" > /tmp/90-$env:USER-sudo-access
            sudo install -m 440 /tmp/90-$env:USER-sudo-access /etc/sudoers.d/90-$env:USER-sudo-access
            rm -f /tmp/90-$env:USER-sudo-access
        }
    }
    catch {
        write-host "Error configuring passwordless logon"
    }

}