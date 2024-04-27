function Get-PreferredIPAddress($isWindows) {
    if ($isWindows) {
        return (Get-NetIPAddress | Where-Object { $_.PrefixOrigin -ne "WellKnown" }).IPAddress
    }
    elseif ($IsMacOS) {
        return /sbin/ifconfig -l | /usr/bin/xargs -n1 /usr/sbin/ipconfig getifaddr
    }
    elseif ($IsLinux) {
        return ip -4 -br addr show | sed -n -e 's/^.*UP\s* //p' | cut -d "/" -f 1
    }
    else {
        return ''
    }
}
