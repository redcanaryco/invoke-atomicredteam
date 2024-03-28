if ($isWindows) {
    Set-Variable -Name "ARTPath" -Value "C:\AtomicRedTeam"
}
else {
    apt-get update;
    apt-get install -y gnupg ca-certificates apt-transport-https software-properties-common wget;
    apt-get install -y build-essential at ccrypt clang cron curl ed golang iproute2 iputils-ping kmod libpam0g-dev less lsof netcat net-tools nmap p7zip python2 rsync samba selinux-utils ssh sshpass sudo tcpdump telnet tor ufw vim whois zip
    Set-Variable -Name "ARTPath" -Value "$HOME/AtomicRedTeam"
}


Write-Output @"
Import-Module "$ARTPath/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1" -Force;
`$PSDefaultParameterValues`["Invoke-AtomicTest:PathToAtomicsFolder"] = "$ARTPath/atomics";
`$PSDefaultParameterValues`["Invoke-AtomicTest:ExecutionLogPath"]="1.csv";
"@ > $PROFILE
