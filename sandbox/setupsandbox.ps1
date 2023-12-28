Set-ExecutionPolicy Bypass -Scope Process -Force;
Write-Host "Installing NuGet"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Write-Host "Installing Atomic Red Team"
Invoke-Expression (Invoke-WebRequest 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1'-UseBasicParsing);
Install-AtomicRedTeam -getAtomics -Force;
New-Item $PROFILE -Force;
Set-Variable -Name "ARTPath" -Value "C:\AtomicRedTeam"

Write-Output @"
Import-Module "$ARTPath/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1" -Force;
`$PSDefaultParameterValues`["Invoke-AtomicTest:PathToAtomicsFolder"] = "$ARTPath/atomics";
`$PSDefaultParameterValues`["Invoke-AtomicTest:ExecutionLogPath"]="1.csv";
"@ > $PROFILE

. $PROFILE

Set-Location C:\AtomicRedTeam
