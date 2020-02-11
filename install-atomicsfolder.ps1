function Install-AtomicsFolder {
  
    <#
    .SYNOPSIS

        This is a simple script to download the atttack definitions in the "atomics" folder of the Red Canary Atomic Red Team project.

        License: MIT License
        Required Dependencies: powershell-yaml
        Optional Dependencies: None

    .PARAMETER DownloadPath

        Specifies the desired path to download atomics zip archive to.

    .PARAMETER InstallPath

        Specifies the desired path for where to unzip the atomics folder.

    .PARAMETER Force

        Delete the existing atomics folder before installation if it exists.

    .EXAMPLE

        Install atomics folder
        PS> Install-AtomicsFolder.ps1

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

        [Parameter(Mandatory = $False)]
        [switch]$Force = $False # delete the existing install directory and reinstall
    )
    $InstallPathwAtomics = Join-Path $InstallPath "atomics"
    if ($Force -or -Not (Test-Path -Path $InstallPathwAtomics )) {
        write-verbose "Directory Creation"
        if ($Force) {
            Try { 
                if (Test-Path $InstallPathwAtomics) { Remove-Item -Path $InstallPathwAtomics -Recurse -Force -ErrorAction Stop | Out-Null }
            }
            Catch {
                Write-Host -ForegroundColor Red $_.Exception.Message
                return
            }
        }
        if (-not (Test-Path $InstallPath)) { New-Item -ItemType directory -Path $InstallPath | Out-Null }

        $url = "https://github.com/$RepoOwner/atomic-red-team/archive/$Branch.zip"
        $path = Join-Path $DownloadPath "$Branch.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        write-verbose "Beginning download of atomics folder from Github"
        Invoke-WebRequest $url -OutFile $path

        write-verbose "Extracting ART to $InstallPath"
        $zipDest = Join-Path "$DownloadPath" "tmp"
        expand-archive -LiteralPath $path -DestinationPath "$zipDest" -Force:$Force
        $atomicsFolderUnzipped = Join-Path (Join-Path $zipDest "atomic-red-team-$Branch") "atomics"
        Move-Item $atomicsFolderUnzipped $InstallPath
        Remove-Item $zipDest -Recurse -Force
        Remove-Item $path

    }
    else {
        Write-Host -ForegroundColor Yellow "An atomics folder already exists at $InstallPathwAtomics. No changes were made."
        Write-Host -ForegroundColor Cyan "Try the install again with the '-Force' parameter if you want to delete the existing installion and re-install."
        Write-Host -ForegroundColor Red "Warning: All files within the atomics folder ($InstallPathwAtomics) will be deleted when using the '-Force' parameter."
    }
}