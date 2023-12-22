New-Item $PROFILE -Force
Invoke-Expression (Invoke-WebRequest 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); 
Install-AtomicRedTeam -getAtomics
Set-Variable -Name "ARTPath" -Value "$HOME/AtomicRedTeam"
Write-Output @"
Import-Module /workspaces/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1
`$PSDefaultParameterValues`["Invoke-AtomicTest:PathToAtomicsFolder"] = "$ARTPath/atomics";
`$PSDefaultParameterValues`["Invoke-AtomicTest:ExecutionLogPath"]="1.csv";
"@ > $PROFILE