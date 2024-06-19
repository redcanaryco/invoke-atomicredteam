# The class definitions that these functions rely upon are located in Private\AtomicClassSchema.ps1

function New-AtomicTechnique {
    <#
.SYNOPSIS

Specifies a new atomic red team technique. The output of this function is designed to be piped directly to ConvertTo-Yaml, eliminating the need to work with YAML directly.

.PARAMETER AttackTechnique

Specifies one or more MITRE ATT&CK techniques that to which this technique applies. Per MITRE naming convention, an attack technique should start with "T" followed by a 4 digit number. The MITRE sub-technique format is also supported: TNNNN.NNN

.PARAMETER DisplayName

Specifies the name of the technique as defined by ATT&CK. Example: 'Audio Capture'

.PARAMETER AtomicTests

Specifies one or more atomic tests. Atomic tests are created using the New-AtomicTest function.

.EXAMPLE

$InputArg1 = New-AtomicTestInputArgument -Name filename -Description 'location of the payload' -Type Path -Default 'PathToAtomicsFolder\T1118\src\T1118.dll'
$InputArg2 = New-AtomicTestInputArgument -Name source -Description 'location of the source code to compile' -Type Path -Default 'PathToAtomicsFolder\T1118\src\T1118.cs'

$AtomicTest1 = New-AtomicTest -Name 'InstallUtil uninstall method call' -Description 'Executes the Uninstall Method' -SupportedPlatforms Windows -InputArguments @($InputArg1, $InputArg2) -ExecutorType CommandPrompt -ExecutorCommand @'
C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /target:library /out:#{filename}  #{source}
C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=false /U #{filename}
'@

# Note: the input arguments are identical for atomic test #1 and #2
$AtomicTest2 = New-AtomicTest -Name 'InstallUtil GetHelp method call' -Description 'Executes the Help property' -SupportedPlatforms Windows -InputArguments @($InputArg1, $InputArg2) -ExecutorType CommandPrompt -ExecutorCommand @'
C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /target:library /out:#{filename} #{source}
C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe /? #{filename}
'@

$AtomicTechnique = New-AtomicTechnique -AttackTechnique T1118 -DisplayName InstallUtil -AtomicTests $AtomicTest1, $AtomicTest2

# Everything is ready to convert to YAML now!
$AtomicTechnique | ConvertTo-Yaml | Out-File T1118.yaml

.OUTPUTS

AtomicTechnique

Outputs an object representing an atomic technique.

The output of New-AtomicTechnique is designed to be piped to ConvertTo-Yaml.
#>

    [CmdletBinding()]
    [OutputType([AtomicTechnique])]
    param (
        [Parameter(Mandatory)]
        [String[]]
        $AttackTechnique,

        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $DisplayName,

        [Parameter(Mandatory)]
        [AtomicTest[]]
        [ValidateNotNull()]
        $AtomicTests
    )

    $AtomicTechniqueInstance = [AtomicTechnique]::new()

    foreach ($Technique in $AttackTechnique) {
        # Attack techniques should match the MITRE ATT&CK [sub-]technique format.
        # This is not a requirement so just warn the user.
        if ($Technique -notmatch '^(?-i:T\d{4}(\.\d{3}){0,1})$') {
            Write-Warning "The following supplied attack technique does not start with 'T' followed by a four digit number: $Technique"
        }
    }

    $AtomicTechniqueInstance.attack_technique = $AttackTechnique
    $AtomicTechniqueInstance.display_name = $DisplayName
    $AtomicTechniqueInstance.atomic_tests = $AtomicTests

    return $AtomicTechniqueInstance
}

function New-AtomicTest {
    <#
.SYNOPSIS

Specifies an atomic test.

.PARAMETER Name

Specifies the name of the test that indicates how it tests the technique.

.PARAMETER Description

Specifies a long form description of the test. Markdown is supported.

.PARAMETER SupportedPlatforms

Specifies the OS/platform on which the test is designed to run. The following platforms are currently supported: Windows, macOS, Linux.

A single test can support multiple platforms.

.PARAMETER ExecutorType

Specifies the the framework or application in which the test should be executed. The following executor types are currently supported: CommandPrompt, Sh, Bash, PowerShell.

- CommandPrompt: The Windows Command Prompt, aka cmd.exe
  Requires the -ExecutorCommand argument to contain a multi-line script that will be preprocessed and then executed by cmd.exe.

- PowerShell: PowerShell
  Requires the -ExecutorCommand argument to contain a multi-line PowerShell scriptblock that will be preprocessed and then executed by powershell.exe

- Sh: Linux's bourne shell
  Requires the -ExecutorCommand argument to contain a multi-line script that will be preprocessed and then executed by sh.

- Bash: Linux's bourne again shell
  Requires the -ExecutorCommand argument to contain a multi-line script that will be preprocessed and then executed by bash.

.PARAMETER ExecutorElevationRequired

Specifies that the test must run with elevated privileges.

.PARAMETER ExecutorSteps

Specifies a manual list of steps to execute. This should be specified when the atomic test cannot be executed in an automated fashion, for example when GUI steps are involved that cannot be automated.

.PARAMETER ExecutorCommand

Specifies the command to execute as part of the atomic test. This should be specified when the atomic test can be executed in an automated fashion.

The -ExecutorType specified will dictate the command specified, e.g. PowerShell scriptblock code when the "PowerShell" ExecutorType is specified.

.PARAMETER ExecutorCleanupCommand

Specifies the command to execute if there are any artifacts that need to be cleaned up.

.PARAMETER InputArguments

Specifies one or more input arguments. Input arguments are defined using the New-AtomicTestInputArgument function.

.PARAMETER DependencyExecutorType

Specifies an override execution type for dependencies. By default, dependencies are executed using the framework specified in -ExecutorType.

In most cases, 'PowerShell' is specified as a dependency executor type when 'CommandPrompt' is specified as an executor type.

.PARAMETER Dependencies

Specifies one or more dependencies. Dependencies are defined using the New-AtomicTestDependency function.

.EXAMPLE

$InputArg1 = New-AtomicTestInputArgument -Name filename -Description 'location of the payload' -Type Path -Default 'PathToAtomicsFolder\T1118\src\T1118.dll'
$InputArg2 = New-AtomicTestInputArgument -Name source -Description 'location of the source code to compile' -Type Path -Default 'PathToAtomicsFolder\T1118\src\T1118.cs'

$AtomicTest = New-AtomicTest -Name 'InstallUtil uninstall method call' -Description 'Executes the Uninstall Method' -SupportedPlatforms Windows -InputArguments $InputArg1, $InputArg2 -ExecutorType CommandPrompt -ExecutorCommand @'
C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /target:library /out:#{filename}  #{source}
C:\Windows\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe /logfile= /LogToConsole=false /U #{filename}
'@

.OUTPUTS

AtomicTest

Outputs an object representing an atomic test. This object is intended to be supplied to the New-AtomicTechnique -AtomicTests parameter.

The output of New-AtomicTest can be piped to ConvertTo-Yaml. The resulting output can be added to an existing atomic technique YAML doc.
#>

    [CmdletBinding(DefaultParameterSetName = 'AutomatedExecutor')]
    [OutputType([AtomicTest])]
    param (
        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Name,

        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Description,

        [Parameter(Mandatory)]
        [String[]]
        [ValidateSet('Windows', 'macOS', 'Linux')]
        $SupportedPlatforms,

        [Parameter(Mandatory, ParameterSetName = 'AutomatedExecutor')]
        [String]
        [ValidateSet('CommandPrompt', 'Sh', 'Bash', 'PowerShell')]
        $ExecutorType,

        [Switch]
        $ExecutorElevationRequired,

        [Parameter(Mandatory, ParameterSetName = 'ManualExecutor')]
        [String]
        [ValidateNotNullOrEmpty()]
        $ExecutorSteps,

        [Parameter(Mandatory, ParameterSetName = 'AutomatedExecutor')]
        [String]
        [ValidateNotNullOrEmpty()]
        $ExecutorCommand,

        [String]
        [ValidateNotNullOrEmpty()]
        $ExecutorCleanupCommand,

        [AtomicInputArgument[]]
        $InputArguments,

        [String]
        [ValidateSet('CommandPrompt', 'Sh', 'Bash', 'PowerShell')]
        $DependencyExecutorType,

        [AtomicDependency[]]
        $Dependencies
    )

    $AtomicTestInstance = [AtomicTest]::new()

    $AtomicTestInstance.name = $Name
    $AtomicTestInstance.description = $Description
    $AtomicTestInstance.supported_platforms = $SupportedPlatforms | ForEach-Object { $_.ToLower() }

    $StringsWithPotentialInputArgs = New-Object -TypeName 'System.Collections.Generic.List`1[String]'

    switch ($PSCmdlet.ParameterSetName) {
        'AutomatedExecutor' {
            $ExecutorInstance = [AtomicExecutorDefault]::new()
            $ExecutorInstance.command = $ExecutorCommand
            $StringsWithPotentialInputArgs.Add($ExecutorCommand)
        }

        'ManualExecutor' {
            $ExecutorInstance = [AtomicExecutorManual]::new()
            $ExecutorInstance.steps = $ExecutorSteps
            $StringsWithPotentialInputArgs.Add($ExecutorSteps)
        }
    }

    switch ($ExecutorType) {
        'CommandPrompt' { $ExecutorInstance.name = 'command_prompt' }
        default { $ExecutorInstance.name = $ExecutorType.ToLower() }
    }

    if ($ExecutorCleanupCommand) {
        $ExecutorInstance.cleanup_command = $ExecutorCleanupCommand
        $StringsWithPotentialInputArgs.Add($ExecutorCleanupCommand)
    }

    if ($ExecutorElevationRequired) { $ExecutorInstance.elevation_required = $True }

    if ($Dependencies) {
        foreach ($Dependency in $Dependencies) {
            $StringsWithPotentialInputArgs.Add($Dependency.description)
            $StringsWithPotentialInputArgs.Add($Dependency.prereq_command)
            $StringsWithPotentialInputArgs.Add($Dependency.get_prereq_command)
        }
    }

    if ($DependencyExecutorType) {
        switch ($DependencyExecutorType) {
            'CommandPrompt' { $AtomicTestInstance.dependency_executor_name = 'command_prompt' }
            default { $AtomicTestInstance.dependency_executor_name = $DependencyExecutorType.ToLower() }
        }
    }    $AtomicTestInstance.dependencies = $Dependencies

    [Hashtable] $InputArgHashtable = @{ }

    if ($InputArguments.Count) {
        # Determine if any of the input argument names repeat. They must be unique.
        $InputArguments | Group-Object -Property Name | Where-Object { $_.Count -gt 1 } | ForEach-Object {
            Write-Error "There are $($_.Count) instances of the $($_.Name) input argument. Input argument names must be unique."
            return
        }

        # Convert each input argument to a hashtable where the key is the Name property.

        foreach ($InputArg in $InputArguments) {
            # Create a copy of the passed input argument that doesn't include the "Name" property.
            # Passing in a shallow copy adversely affects YAML serialization for some reason.
            $NewInputArg = [AtomicInputArgument]::new()
            $NewInputArg.default = $InputArg.default
            $NewInputArg.description = $InputArg.description
            $NewInputArg.type = $InputArg.type

            $InputArgHashtable[$InputArg.Name] = $NewInputArg
        }

        $AtomicTestInstance.input_arguments = $InputArgHashtable
    }

    # Extract all specified input arguments from executor and any dependencies.
    $Regex = [Regex] '#\{(?<ArgName>[^}]+)\}'
    [String[]] $InputArgumentNamesFromExecutor = $StringsWithPotentialInputArgs |
    ForEach-Object { $Regex.Matches($_) } |
    Select-Object -ExpandProperty Groups |
    Where-Object { $_.Name -eq 'ArgName' } |
    Select-Object -ExpandProperty Value |
    Sort-Object -Unique


    # Validate that all executor arguments are defined as input arguments
    if ($InputArgumentNamesFromExecutor.Count) {
        $InputArgumentNamesFromExecutor | ForEach-Object {
            if ($InputArgHashtable.Keys -notcontains $_) {
                Write-Error "The following input argument was specified but is not defined: '$_'"
                return
            }
        }
    }

    # Validate that all defined input args are utilized at least once in the executor.
    if ($InputArgHashtable.Keys.Count) {
        $InputArgHashtable.Keys | ForEach-Object {
            if ($InputArgumentNamesFromExecutor -notcontains $_) {
                # Write a warning since this scenario is not considered a breaking change
                Write-Warning "The following input argument is defined but not utilized: '$_'."
            }
        }
    }

    $AtomicTestInstance.executor = $ExecutorInstance

    return $AtomicTestInstance
}

function New-AtomicTestDependency {
    <#
.SYNOPSIS

Specifies a new dependency that must be met prior to execution of an atomic test.

.PARAMETER Description

Specifies a human-readable description of the dependency. This should be worded in the following form: SOMETHING must SOMETHING

.PARAMETER PrereqCommand

Specifies commands to check if prerequisites for running this test are met.

For the "command_prompt" executor, if any command returns a non-zero exit code, the pre-requisites are not met.

For the "powershell" executor, all commands are run as a script block and the script block must return 0 for success.

.PARAMETER GetPrereqCommand

Specifies commands to meet this prerequisite or a message describing how to meet this prereq

More specifically, this command is designed to satisfy either of the following conditions:

1) If a prerequisite is not met, perform steps necessary to satify the prerequisite. Such a command should be implemented when prerequisites can be satisfied in an automated fashion.
2) If a prerequisite is not met, inform the user what the steps are to satisfy the prerequisite. Such a message should be presented to the user in the case that prerequisites cannot be satisfied in an automated fashion.

.EXAMPLE

$Dependency = New-AtomicTestDependency -Description 'Folder to zip must exist (#{input_file_folder})' -PrereqCommand 'test -e #{input_file_folder}' -GetPrereqCommand 'echo Please set input_file_folder argument to a folder that exists'

.OUTPUTS

AtomicDependency

Outputs an object representing an atomic test dependency. This object is intended to be supplied to the New-AtomicTest -Dependencies parameter.

Note: due to a bug in PowerShell classes, the get_prereq_command property will not display by default. If all fields must be explicitly displayed, they can be viewed by piping output to "Select-Object description, prereq_command, get_prereq_command".
#>

    [CmdletBinding()]
    [OutputType([AtomicDependency])]
    param (
        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Description,

        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $PrereqCommand,

        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $GetPrereqCommand
    )

    $DependencyInstance = [AtomicDependency]::new()

    $DependencyInstance.description = $Description
    $DependencyInstance.prereq_command = $PrereqCommand
    $DependencyInstance.get_prereq_command = $GetPrereqCommand

    return $DependencyInstance
}

function New-AtomicTestInputArgument {
    <#
.SYNOPSIS

Specifies an input to an atomic test that is a requirement to run the test (think of these like function arguments).

.PARAMETER Name

Specifies the name of the input argument. This must be lowercase and can optionally, have underscores. The input argument name is what is specified as arguments within executors and dependencies.

.PARAMETER Description

Specifies a human-readable description of the input argument.

.PARAMETER Type

Specifies the data type of the input argument. The following data types are supported: Path, Url, String, Integer, Float. If an alternative data type must be supported, use the -TypeOverride parameter.

.PARAMETER TypeOverride

Specifies an unsupported input argument data type. Specifying this parameter should not be common.

.PARAMETER Default

Specifies a default value for an input argument if one is not specified via the Invoke-AtomicTest -InputArgs parameter.

.EXAMPLE

$AtomicInputArgument = New-AtomicTestInputArgument -Name 'rar_exe' -Type Path -Description 'The RAR executable from Winrar' -Default '%programfiles%\WinRAR\Rar.exe'

.OUTPUTS

AtomicInputArgument

Outputs an object representing an atomic test input argument. This object is intended to be supplied to the New-AtomicTest -InputArguments parameter.
#>

    [CmdletBinding(DefaultParameterSetName = 'PredefinedType')]
    [OutputType([AtomicInputArgument])]
    param (
        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Name,

        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Description,

        [Parameter(Mandatory, ParameterSetName = 'PredefinedType')]
        [String]
        [ValidateSet('Path', 'Url', 'String', 'Integer', 'Float')]
        $Type,

        [Parameter(Mandatory, ParameterSetName = 'TypeOverride')]
        [String]
        [ValidateNotNullOrEmpty()]
        $TypeOverride,

        [Parameter(Mandatory)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Default
    )

    if ($Name -notmatch '^(?-i:[0-9a-z_]+)$') {
        Write-Error "Input argument names must be lowercase and optionally, contain underscores. Input argument name supplied: $Name"
        return
    }

    $AtomicInputArgInstance = [AtomicInputArgument]::new()

    $AtomicInputArgInstance.description = $Description
    $AtomicInputArgInstance.default = $Default

    if ($Type) {
        $AtomicInputArgInstance.type = $Type

        # Validate input argument types when it makes sense to do so.
        switch ($Type) {
            'Url' {
                if (-not [Uri]::IsWellFormedUriString($Type, [UriKind]::RelativeOrAbsolute)) {
                    Write-Warning "The specified Url is not properly formatted: $Type"
                }
            }

            'Integer' {
                if (-not [Int]::TryParse($Type, [Ref] $null)) {
                    Write-Warning "The specified Int is not properly formatted: $Type"
                }
            }

            'Float' {
                if (-not [Double]::TryParse($Type, [Ref] $null)) {
                    Write-Warning "The specified Float is not properly formatted: $Type"
                }
            }

            # The following supported data types do not make sense to validate:
            # 'Path' { }
            # 'String' { }
        }
    }
    else {
        $AtomicInputArgInstance.type = $TypeOverride
    }

    # Add Name as a note property since the Name property cannot be defined in the AtomicInputArgument
    # since it must be stored as a hashtable where the name is the key. Fortunately, ConvertTo-Yaml
    # won't convert note properties during serialization.
    $InputArgument = Add-Member -InputObject $AtomicInputArgInstance -MemberType NoteProperty -Name Name -Value $Name -PassThru

    return $InputArgument
}
