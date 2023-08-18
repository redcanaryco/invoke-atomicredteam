Set-ExecutionPolicy Bypass -Scope Process -Force;
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1'-UseBasicParsing); 
Install-AtomicRedTeam -getAtomics -Force;
New-Item $PROFILE -Force;
Set-Variable -Name "ARTPath" -Value "C:\AtomicRedTeam"

Write-Output @"
Import-Module "$ARTPath/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1" -Force;
`$PSDefaultParameterValues`["Invoke-AtomicTest:PathToAtomicsFolder"] = "$ARTPath/atomics";
`$PSDefaultParameterValues`["Invoke-AtomicTest:ExecutionLogPath"]="1.csv";
"@ > $PROFILE

. $PROFILE