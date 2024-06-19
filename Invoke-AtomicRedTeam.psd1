@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'Invoke-AtomicRedTeam.psm1'

    # Version number of this module.
    ModuleVersion     = '2.1.0'

    # ID used to uniquely identify this module
    GUID              = '8f492621-18f8-432e-9532-b1d54d3e90bd'

    # Author of this module
    Author            = 'Casey Smith @subTee, Josh Rickard @MSAdministrator, Carrie Roberts @OrOneEqualsOne, Matt Graeber @mattifestation'

    # Company or vendor of this module
    CompanyName       = 'Red Canary, Inc.'

    # Copyright statement for this module
    Copyright         = '(c) 2021 Red Canary. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'A PowerShell module that runs Atomic Red Team tests from yaml definition files.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @('powershell-yaml')

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # AtomicClassSchema.ps1 needs to be present in the caller's scope in order for the built-in classes to surface properly.
    ScriptsToProcess  = @('Private\AtomicClassSchema.ps1', 'Public\config.ps1')

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Invoke-AtomicTest',
        'Get-AtomicTechnique',
        'New-AtomicTechnique',
        'New-AtomicTest',
        'New-AtomicTestInputArgument',
        'New-AtomicTestDependency',
        'Start-AtomicGUI',
        'Stop-AtomicGUI',
        'Invoke-SetupAtomicRunner',
        'Invoke-GenerateNewSchedule',
        'Invoke-RefreshExistingSchedule',
        'Invoke-AtomicRunner',
        'Get-Schedule',
        'Invoke-KickoffAtomicRunner',
        'Get-PreferredIPAddress',
        'Invoke-KillProcessTree'
    )

    # Variables to export from this module
    VariablesToExport = '*'

    NestedModules     = @(
        "Public\Default-ExecutionLogger.psm1",
        "Public\Attire-ExecutionLogger.psm1",
        "Public\Syslog-ExecutionLogger.psm1",
        "Public\WinEvent-ExecutionLogger.psm1"
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('Security', 'Defense')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/redcanaryco/invoke-atomicredteam/blob/master/LICENSE.txt'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/redcanaryco/invoke-atomicredteam'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
1.0.2
-----
* Add support for custom execution loggers

1.0.1
-----
* Adding 'powershell-yaml' to RequiredModules in the module manifest

1.0.0
-----
* Initial release for submission to the PowerShell Gallery
'@

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}