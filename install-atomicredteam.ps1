#Requires -Version 5.0
function Install-AtomicRedTeam {

    <#
    .SYNOPSIS

        This is a simple script to download and install the Atomic Red Team Invoke-AtomicRedTeam Powershell Framework.

        Atomic Function: Install-AtomicRedTeam
        Author: Red Canary Research
        License: MIT License
        Required Dependencies: powershell-yaml
        Optional Dependencies: None

    .PARAMETER DownloadPath

        Specifies the desired path to download Atomic Red Team.

    .PARAMETER InstallPath

        Specifies the desired path for where to install Atomic Red Team.

    .PARAMETER Force

        Delete the existing InstallPath before installation if it exists.

    .EXAMPLE

        Install Atomic Red Team
        PS> Install-AtomicRedTeam.ps1

    .NOTES

        Use the '-Verbose' option to print detailed information.

#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False, Position = 0)]
        [string]$InstallPath = $( if ($IsLinux -or $IsMacOS) { $Env:HOME + "/AtomicRedTeam" } else { $env:HOMEDRIVE + "\AtomicRedTeam" }),

        [Parameter(Mandatory = $False, Position = 1)]
        [string]$DownloadPath = $InstallPath,

        [Parameter(Mandatory = $False, Position = 2)]
        [string]$RepoOwner = "redcanaryco",

        [Parameter(Mandatory = $False, Position = 3)]
        [string]$Branch = "master",

        [Parameter(Mandatory = $False, Position = 4)]
        [switch]$getAtomics = $False,

        [Parameter(Mandatory = $False)]
        [switch]$Force = $False, # delete the existing install directory and reinstall

        [Parameter(Mandatory = $False)]
        [switch]$NoPayloads = $False # only download atomic yaml files during -getAtomics operation (no /src or /bin dirs)
    )
    Try {
        (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

        $InstallPathwIart = Join-Path $InstallPath "invoke-atomicredteam"
        $modulePath = Join-Path "$InstallPath" "invoke-atomicredteam\Invoke-AtomicRedTeam.psd1"
        if ($Force -or -Not (Test-Path -Path $InstallPathwIart )) {
            write-verbose "Directory Creation"
            if ($Force) {
                Try {
                    if (Test-Path $InstallPathwIart) { Remove-Item -Path $InstallPathwIart -Recurse -Force -ErrorAction Stop | Out-Null }
                }
                Catch {
                    Write-Host -ForegroundColor Red $_.Exception.Message
                    return
                }
            }
            if (-not (Test-Path $InstallPath)) { New-Item -ItemType directory -Path $InstallPath | Out-Null }

            $url = "https://github.com/$RepoOwner/invoke-atomicredteam/archive/$Branch.zip"
            $path = Join-Path $DownloadPath "$Branch.zip"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            write-verbose "Beginning download from Github"
            Invoke-WebRequest $url -OutFile $path

            write-verbose "Extracting ART to $InstallPath"
            $zipDest = Join-Path "$DownloadPath" "tmp"
            Microsoft.PowerShell.Archive\Expand-Archive -LiteralPath $path -DestinationPath "$zipDest" -Force:$Force
            $iartFolderUnzipped = Join-Path $zipDest "invoke-atomicredteam-$Branch"
            Move-Item $iartFolderUnzipped $InstallPathwIart
            Remove-Item $zipDest -Recurse -Force
            Remove-Item $path

            if (-not (Get-InstalledModule -Name "powershell-yaml" -ErrorAction:SilentlyContinue)) {
                write-verbose "Installing powershell-yaml"
                Install-Module -Name powershell-yaml -Scope CurrentUser -Force
            }

            write-verbose "Importing invoke-atomicRedTeam module"
            Import-Module $modulePath -Force

            if ($getAtomics) {
                Write-Verbose "Installing Atomics Folder"
                Invoke-Expression (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/$RepoOwner/invoke-atomicredteam/$Branch/install-atomicsfolder.ps1"); Install-AtomicsFolder -InstallPath $InstallPath -DownloadPath $DownloadPath -Force:$Force -RepoOwner $RepoOwner -NoPayloads:$NoPayloads
            }

            Write-Host "Installation of Invoke-AtomicRedTeam is complete. You can now use the Invoke-AtomicTest function" -Fore Yellow
            Write-Host "See Wiki at https://github.com/$repoOwner/invoke-atomicredteam/wiki for complete details" -Fore Yellow
        }
        else {
            Write-Host -ForegroundColor Yellow "Atomic Redteam already exists at $InstallPathwIart. No changes were made."
            Write-Host -ForegroundColor Cyan "Try the install again with the '-Force' parameter if you want to delete the existing installion and re-install."
            Write-Host -ForegroundColor Red "Warning: All files within the install directory ($InstallPathwIart) will be deleted when using the '-Force' parameter."
        }
    }
    Catch {
        Write-Error "Installation of AtomicRedTeam Failed."
        Write-Host $_.Exception.Message`n
    }
}
