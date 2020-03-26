#requires -Version 5.0

#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -Exclude "AtomicClassSchema.ps1" -ErrorAction SilentlyContinue )

# Make sure the Atomic Class Schema is available first
. "C:\AtomicRedTeam\invoke-atomicredteam\Private\AtomicClassSchema.ps1"

#Dot source the files
Foreach ($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}