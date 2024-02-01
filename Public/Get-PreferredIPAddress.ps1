function Get-PreferredIPAddress($isWindows) {
    if ($isWindows) {
        return (Get-NetIPAddress | Where-Object { $_.PrefixOrigin -ne "WellKnown" }).IPAddress
    }
    elseif ($IsMacOS) {
        return bash -c "ifconfig -l | xargs -n1 ipconfig getifaddr"
    }
    elseif ($IsLinux) {
        return ip -4 -br addr show | sed -n -e 's/^.*UP\s* //p' | cut -d "/" -f 1
    }
    else {
        return ''
    }
}

