# -- Invoke Atomic-Red-Team Dockerfile
# Build Image: docker buildx build --progress plain -t invoke-atomicredteam .
# Running All: docker run --rm invoke-atomicredteam
# Interactive: docker run --rm -it invoke-atomicredteam -i
FROM ubuntu:22.04

# -- Basics
RUN apt-get update && \
    apt-get install -y gnupg ca-certificates apt-transport-https software-properties-common wget

# -- Install test dependancies
RUN apt-get install -y build-essential at ccrypt clang cron curl ed golang iproute2 iputils-ping kmod libpam0g-dev less lsof netcat net-tools nmap p7zip python2 rsync samba selinux-utils ssh sshpass sudo tcpdump telnet tor ufw vim whois zip

# -- Setup shell environment
RUN ln -sf /usr/bin/bash /usr/bin/sh
SHELL ["sh", "-l", "-c"]

RUN echo export PWSH_ARCH=`case $(uname -m) in \
    x86_64) echo x64;; \
    aarch64) echo arm64;; \
    esac` >>/etc/profile.d/pwsh.sh

RUN echo export PWSH_VER=`curl -v https://github.com/PowerShell/PowerShell/releases/latest 2>&1 | grep -i location: | sed -e 's|^.*/tag/v||' | tr -d '\r'` \
    >>/etc/profile.d/pwsh.sh

# -- Install Powershell
# Create the target folder where powershell will be placed
RUN mkdir -p /opt/microsoft/powershell
# Download the powershell '.tar.gz' archive and expand powershell to the target folder
RUN curl -L https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VER}/powershell-${PWSH_VER}-linux-${PWSH_ARCH}.tar.gz \
    | tar zxf - -C /opt/microsoft/powershell

# Set execute permissions
RUN chmod +x /opt/microsoft/powershell/pwsh
# Create the symbolic link that points to pwsh
RUN ln -s /opt/microsoft/powershell/pwsh /usr/local/bin/pwsh

WORKDIR /root
# -- Setup pwsh profile
RUN mkdir -p .config/powershell/
RUN echo -e '\
    if (Test-Path -Path "/root/AtomicRedTeam") { \n\
    Import-Module "/root/AtomicRedTeam/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1" -Force \n\
    $PSDefaultParameterValues = @{"Invoke-AtomicTest:PathToAtomicsFolder"="/root/AtomicRedTeam/atomics"} \n\
    }' >.config/powershell/profile.ps1

# -- Install Atomic Red Team from pwsh
SHELL ["pwsh", "-Command"]
RUN IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); \
    Install-AtomicRedTeam -getAtomics

RUN Invoke-AtomicTest ALL -GetPrereqs

# --- Setup pwsh entrypoint and default Invoke-AtomicTest command
ENTRYPOINT ["pwsh"]
CMD ["-Command", "Invoke-AtomicTest ALL -Force"]
