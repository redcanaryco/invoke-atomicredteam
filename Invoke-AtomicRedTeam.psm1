#requires -Version 5.0

# execute amsi bypass if configured to use one
if([bool]$artConfig.absb -and ($artConfig.OS -eq "windows")){
    $artConfig.absb.Invoke()
}

#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -Exclude AtomicRunnerService.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -Exclude "AtomicClassSchema.ps1" -ErrorAction SilentlyContinue )

# Make sure the Atomic Class Schema is available first (a workaround so PSv5.0 doesn't give errors)
. "$PSScriptRoot\Private\AtomicClassSchema.ps1"

#Dot source the files
Foreach ($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
