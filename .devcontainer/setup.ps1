New-Item $PROFILE -Force
Invoke-Expression (Invoke-WebRequest 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing -ProgressAction SilentlyContinue); 
Install-AtomicRedTeam -getAtomics
Write-Output @"
Import-Module /workspaces/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1
`$PSDefaultParameterValues`["Invoke-AtomicTest:PathToAtomicsFolder"] = "$HOME/AtomicRedTeam/atomics";
`$PSDefaultParameterValues`["Invoke-AtomicTest:ExecutionLogPath"]="$HOME/AtomicRedTeam/execution.csv";
"@ > $PROFILE