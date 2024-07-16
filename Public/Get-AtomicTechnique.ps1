filter Get-AtomicTechnique {
    <#
    .SYNOPSIS

    Retrieve and validate an atomic technique.

    .DESCRIPTION

    Get-AtomicTechnique retrieves and validates one or more atomic techniques. Get-AtomicTechnique supports retrieval from YAML files or from a raw YAML string.

    This function facilitates the following use cases:

    1) Validation prior to execution of atomic tests.
    2) Writing code to reason over one or more atomic techniques/tests.
    3) Representing atomic techniques/tests in a format that is more conducive to PowerShell. ConvertFrom-Yaml returns a large, complicated hashtable that is difficult to work with and reason over. Get-AtomicTechnique helps abstract those challenges away.
    4) Representing atomic techniques/tests in a format that can be piped directly to ConvertTo-Yaml.

    .PARAMETER Path

    Specifies the path to an atomic technique YAML file. Get-AtomicTechnique expects that the file extension be .yaml or .yml and that it is well-formed YAML content.

    .PARAMETER Yaml

    Specifies a single string consisting of raw atomic technique YAML.

    .EXAMPLE

    Get-ChildItem -Path C:\atomic-red-team\atomics\* -Recurse -Include 'T*.yaml' | Get-AtomicTechnique

    .EXAMPLE

    Get-Item C:\atomic-red-team\atomics\T1117\T1117.yaml | Get-AtomicTechnique

    .EXAMPLE

    Get-AtomicTechnique -Path C:\atomic-red-team\atomics\T1117\T1117.yaml

    .EXAMPLE

    $Yaml = @'
    ---
    attack_technique: T1152
    display_name: Launchctl

    atomic_tests:
    - name: Launchctl
      description: |
        Utilize launchctl

      supported_platforms:
        - macos

      executor:
        name: sh
        command: |
          launchctl submit -l evil -- /Applications/Calculator.app/Contents/MacOS/Calculator
    '@

    Get-AtomicTechnique -Yaml $Yaml

    .INPUTS

    System.IO.FileInfo

    The output of Get-Item and Get-ChildItem can be piped directly into Get-AtomicTechnique.

    .OUTPUTS

    AtomicTechnique

    Outputs an object representing a parsed and validated atomic technique.
    #>

    [CmdletBinding(DefaultParameterSetName = 'FilePath')]
    [OutputType([AtomicTechnique])]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'FilePath')]
        [String]
        [Alias('FullName')]
        [ValidateScript({ Test-Path -Path $_ -Include '*.yaml', '*.yml' })]
        $Path,

        [Parameter(Mandatory, ParameterSetName = 'Yaml')]
        [String]
        [ValidateNotNullOrEmpty()]
        $Yaml
    )


    switch ($PSCmdlet.ParameterSetName) {
        'FilePath' {
            $ResolvedPath = Resolve-Path -Path $Path

            $YamlContent = Get-Content -Path $ResolvedPath -Raw
            $ErrorStringPrefix = "[$($ResolvedPath)]"
        }

        'Yaml' {
            $YamlContent = $Yaml
            $ErrorStringPrefix = ''
        }
    }

    $ParsedYaml = $null

    $ValidSupportedPlatforms = @('windows', 'macos', 'linux', 'office-365', 'azure-ad', 'google-workspace', 'saas', 'iaas', 'containers', 'iaas:aws', 'iaas:azure', 'iaas:gcp')
    $ValidInputArgTypes = @('Path', 'Url', 'String', 'Integer', 'Float')
    $ValidExecutorTypes = @('command_prompt', 'sh', 'bash', 'powershell', 'manual', 'aws', 'az', 'gcloud', 'kubectl')

    # ConvertFrom-Yaml will throw a .NET exception rather than a PowerShell error.
    # Capture the exception and convert to PowerShell error so that the user can decide
    # how to handle the error.
    try {
        [Hashtable] $ParsedYaml = ConvertFrom-Yaml -Yaml $YamlContent
    }
    catch {
        Write-Error $_
    }

    if ($ParsedYaml) {
        # The document was well-formed YAML. Now, validate against the atomic red schema

        $AtomicInstance = [AtomicTechnique]::new()

        if (-not $ParsedYaml.Count) {
            Write-Error "$ErrorStringPrefix YAML file has no elements."
            return
        }

        if (-not $ParsedYaml.ContainsKey('attack_technique')) {
            Write-Error "$ErrorStringPrefix 'attack_technique' element is required."
            return
        }

        $AttackTechnique = $null

        if ($ParsedYaml['attack_technique'].Count -gt 1) {
            # An array of attack techniques are supported.
            foreach ($Technique in $ParsedYaml['attack_technique']) {
                if ("$Technique" -notmatch '^(?-i:T\d{4}(\.\d{3}){0,1})$') {
                    Write-Warning "$ErrorStringPrefix Attack technique: $Technique. Each attack technique should start with the letter 'T' followed by a four digit number."
                }

                [String[]] $AttackTechnique = $ParsedYaml['attack_technique']
            }
        }
        else {
            if ((-not "$($ParsedYaml['attack_technique'])".StartsWith('T'))) {
                # If the attack technique is a single entry, validate that it starts with the letter T.
                Write-Warning "$ErrorStringPrefix Attack technique: $($ParsedYaml['attack_technique']). Attack techniques should start with the letter T."
            }

            [String] $AttackTechnique = $ParsedYaml['attack_technique']
        }

        $AtomicInstance.attack_technique = $AttackTechnique

        if (-not $ParsedYaml.ContainsKey('display_name')) {
            Write-Error "$ErrorStringPrefix 'display_name' element is required."
            return
        }

        if (-not ($ParsedYaml['display_name'] -is [String])) {
            Write-Error "$ErrorStringPrefix 'display_name' must be a string."
            return
        }

        $AtomicInstance.display_name = $ParsedYaml['display_name']

        if (-not $ParsedYaml.ContainsKey('atomic_tests')) {
            Write-Error "$ErrorStringPrefix 'atomic_tests' element is required."
            return
        }

        if (-not ($ParsedYaml['atomic_tests'] -is [System.Collections.Generic.List`1[Object]])) {
            Write-Error "$ErrorStringPrefix 'atomic_tests' element must be an array."
            return
        }

        $AtomicTests = [AtomicTest[]]::new($ParsedYaml['atomic_tests'].Count)

        if (-not $ParsedYaml['atomic_tests'].Count) {
            Write-Error "$ErrorStringPrefix 'atomic_tests' element is empty - you have no tests."
            return
        }

        for ($i = 0; $i -lt $ParsedYaml['atomic_tests'].Count; $i++) {
            $AtomicTest = $ParsedYaml['atomic_tests'][$i]

            $AtomicTestInstance = [AtomicTest]::new()

            $StringsWithPotentialInputArgs = New-Object -TypeName 'System.Collections.Generic.List`1[String]'

            if (-not $AtomicTest.ContainsKey('name')) {
                Write-Error "$ErrorStringPrefix 'atomic_tests[$i].name' element is required."
                return
            }

            if (-not ($AtomicTest['name'] -is [String])) {
                Write-Error "$ErrorStringPrefix 'atomic_tests[$i].name' element must be a string."
                return
            }

            $AtomicTestInstance.name = $AtomicTest['name']
            $AtomicTestInstance.auto_generated_guid = $AtomicTest['auto_generated_guid']

            if (-not $AtomicTest.ContainsKey('description')) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].description' element is required."
                return
            }

            if (-not ($AtomicTest['description'] -is [String])) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].description' element must be a string."
                return
            }

            $AtomicTestInstance.description = $AtomicTest['description']

            if (-not $AtomicTest.ContainsKey('supported_platforms')) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].supported_platforms' element is required."
                return
            }

            if (-not ($AtomicTest['supported_platforms'] -is [System.Collections.Generic.List`1[Object]])) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].supported_platforms' element must be an array."
                return
            }

            foreach ($SupportedPlatform in $AtomicTest['supported_platforms']) {
                if ($ValidSupportedPlatforms -cnotcontains $SupportedPlatform) {
                    Write-Warning "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].supported_platforms': '$SupportedPlatform' must be one of the following: $($ValidSupportedPlatforms -join ', ')."
                }
            }

            $AtomicTestInstance.supported_platforms = $AtomicTest['supported_platforms']

            $Dependencies = $null

            if ($AtomicTest['dependencies'].Count) {
                $Dependencies = [AtomicDependency[]]::new($AtomicTest['dependencies'].Count)
                $j = 0

                # dependencies are optional and there can be multiple
                foreach ($Dependency in $AtomicTest['dependencies']) {
                    $DependencyInstance = [AtomicDependency]::new()

                    if (-not $Dependency.ContainsKey('description')) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].dependencies[$j].description' element is required."
                        return
                    }

                    if (-not ($Dependency['description'] -is [String])) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].dependencies[$j].description' element must be a string."
                        return
                    }

                    $DependencyInstance.description = $Dependency['description']
                    $StringsWithPotentialInputArgs.Add($Dependency['description'])

                    if (-not $Dependency.ContainsKey('prereq_command')) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].dependencies[$j].prereq_command' element is required."
                        return
                    }

                    if (-not ($Dependency['prereq_command'] -is [String])) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].dependencies[$j].prereq_command' element must be a string."
                        return
                    }

                    $DependencyInstance.prereq_command = $Dependency['prereq_command']
                    $StringsWithPotentialInputArgs.Add($Dependency['prereq_command'])

                    if (-not $Dependency.ContainsKey('get_prereq_command')) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].dependencies[$j].get_prereq_command' element is required."
                        return
                    }

                    if (-not ($Dependency['get_prereq_command'] -is [String])) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].dependencies[$j].get_prereq_command' element must be a string."
                        return
                    }

                    $DependencyInstance.get_prereq_command = $Dependency['get_prereq_command']
                    $StringsWithPotentialInputArgs.Add($Dependency['get_prereq_command'])

                    $Dependencies[$j] = $DependencyInstance

                    $j++
                }

                $AtomicTestInstance.dependencies = $Dependencies
            }

            if ($AtomicTest.ContainsKey('dependency_executor_name')) {
                if ($ValidExecutorTypes -notcontains $AtomicTest['dependency_executor_name']) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].dependency_executor_name': '$($AtomicTest['dependency_executor_name'])' must be one of the following: $($ValidExecutorTypes -join ', ')."
                    return
                }

                if ($null -eq $AtomicTestInstance.Dependencies) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] If 'atomic_tests[$i].dependency_executor_name' is defined, there must be at least one dependency defined."
                }

                $AtomicTestInstance.dependency_executor_name = $AtomicTest['dependency_executor_name']
            }

            $InputArguments = $null

            # input_arguments is optional
            if ($AtomicTest.ContainsKey('input_arguments')) {
                if (-not ($AtomicTest['input_arguments'] -is [Hashtable])) {
                    $AtomicTest['input_arguments'].GetType().FullName
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].input_arguments' must be a hashtable."
                    return
                }

                if (-not ($AtomicTest['input_arguments'].Count)) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].input_arguments' must have at least one entry."
                    return
                }

                $InputArguments = @{}

                $j = 0

                foreach ($InputArgName in $AtomicTest['input_arguments'].Keys) {

                    $InputArgument = [AtomicInputArgument]::new()

                    if (-not $AtomicTest['input_arguments'][$InputArgName].ContainsKey('description')) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].input_arguments['$InputArgName'].description' element is required."
                        return
                    }

                    if (-not ($AtomicTest['input_arguments'][$InputArgName]['description'] -is [String])) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].input_arguments['$InputArgName'].description' element must be a string."
                        return
                    }

                    $InputArgument.description = $AtomicTest['input_arguments'][$InputArgName]['description']

                    if (-not $AtomicTest['input_arguments'][$InputArgName].ContainsKey('type')) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].input_arguments['$InputArgName'].type' element is required."
                        return
                    }

                    if ($ValidInputArgTypes -notcontains $AtomicTest['input_arguments'][$InputArgName]['type']) {
                        Write-Warning "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].input_arguments['$InputArgName'].type': '$($AtomicTest['input_arguments'][$InputArgName]['type'])' should be one of the following: $($ValidInputArgTypes -join ', ')"
                    }

                    $InputArgument.type = $AtomicTest['input_arguments'][$InputArgName]['type']

                    if (-not $AtomicTest['input_arguments'][$InputArgName].ContainsKey('default')) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].input_arguments['$InputArgName'].default' element is required."
                        return
                    }

                    $InputArgument.default = $AtomicTest['input_arguments'][$InputArgName]['default']

                    $InputArguments[$InputArgName] = $InputArgument

                    $j++
                }
            }

            $AtomicTestInstance.input_arguments = $InputArguments

            if (-not $AtomicTest.ContainsKey('executor')) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor' element is required."
                return
            }

            if (-not ($AtomicTest['executor'] -is [Hashtable])) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor' element must be a hashtable."
                return
            }

            if (-not $AtomicTest['executor'].ContainsKey('name')) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor.name' element is required."
                return
            }

            if (-not ($AtomicTest['executor']['name'] -is [String])) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].description.name' element must be a string."
                return
            }

            if ($AtomicTest['executor']['name'] -notmatch '^(?-i:[a-z_]+)$') {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].description.name' element must be lowercased and underscored."
                return
            }

            if ($ValidExecutorTypes -notcontains $AtomicTest['executor']['name']) {
                Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].description.name': '$($AtomicTest['executor']['name'])' must be one of the following: $($ValidExecutorTypes -join ', ')"
                return
            }

            if ($AtomicTest['executor']['name'] -eq 'manual') {
                if (-not $AtomicTest['executor'].ContainsKey('steps')) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor.steps' element is required when the 'manual' executor is used."
                    return
                }

                if (-not ($AtomicTest['executor']['steps'] -is [String])) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor.steps' element must be a string."
                    return
                }

                $ExecutorInstance = [AtomicExecutorManual]::new()
                $ExecutorInstance.steps = $AtomicTest['executor']['steps']
                $StringsWithPotentialInputArgs.Add($AtomicTest['executor']['steps'])
            }
            else {
                if (-not $AtomicTest['executor'].ContainsKey('command')) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor.command' element is required when the '$($ValidExecutorTypes -join ', ')' executors are used."
                    return
                }

                if (-not ($AtomicTest['executor']['command'] -is [String])) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor.command' element must be a string."
                    return
                }

                $ExecutorInstance = [AtomicExecutorDefault]::new()
                $ExecutorInstance.command = $AtomicTest['executor']['command']
                $StringsWithPotentialInputArgs.Add($AtomicTest['executor']['command'])
            }

            # cleanup_command element is optional
            if ($AtomicTest['executor'].ContainsKey('cleanup_command')) {
                $ExecutorInstance.cleanup_command = $AtomicTest['executor']['cleanup_command']
                $StringsWithPotentialInputArgs.Add($AtomicTest['executor']['cleanup_command'])
            }

            # elevation_required element is optional
            if ($AtomicTest['executor'].ContainsKey('elevation_required')) {
                if (-not ($AtomicTest['executor']['elevation_required'] -is [Bool])) {
                    Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] 'atomic_tests[$i].executor.elevation_required' element must be a boolean."
                    return
                }

                $ExecutorInstance.elevation_required = $AtomicTest['executor']['elevation_required']
            }
            else {
                # if elevation_required is not present, default to false
                $ExecutorInstance.elevation_required = $False
            }

            $InputArgumentNames = $null

            # Get all input argument names
            $InputArgumentNames = $InputArguments.Keys

            # Extract all input arguments names from the executor
            # Potential places where input arguments can be populated:
            #  - Dependency description
            #  - Dependency prereq_command
            #  - Dependency get_prereq_command
            #  - Executor steps
            #  - Executor command
            #  - Executor cleanup_command

            $Regex = [Regex] '#\{(?<ArgName>[^}]+)\}'
            [String[]] $InputArgumentNamesFromExecutor = $StringsWithPotentialInputArgs |
            ForEach-Object { $Regex.Matches($_) } |
            Select-Object -ExpandProperty Groups |
            Where-Object { $_.Name -eq 'ArgName' } |
            Select-Object -ExpandProperty Value |
            Sort-Object -Unique


            # Validate that all executor input arg names are defined input arg names.
            if ($InputArgumentNamesFromExecutor.Count) {
                $InputArgumentNamesFromExecutor | ForEach-Object {
                    if ($InputArgumentNames -notcontains $_) {
                        Write-Error "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] The following input argument was specified but is not defined: '$_'"
                        return
                    }
                }
            }

            # Validate that all defined input args are utilized at least once in the executor.
            if ($InputArgumentNames.Count) {
                $InputArgumentNames | ForEach-Object {
                    if ($InputArgumentNamesFromExecutor -notcontains $_) {
                        # Write a warning since this scenario is not considered a breaking change
                        Write-Warning "$ErrorStringPrefix[Atomic test name: $($AtomicTestInstance.name)] The following input argument is defined but not utilized: '$_'."
                    }
                }
            }

            $ExecutorInstance.name = $AtomicTest['executor']['name']

            $AtomicTestInstance.executor = $ExecutorInstance

            $AtomicTests[$i] = $AtomicTestInstance
        }

        $AtomicInstance.atomic_tests = $AtomicTests

        $AtomicInstance
    }
}


# Tab completion for Atomic Tests
function Get-TechniqueNumbers {
    $PathToAtomicsFolder = if ($IsLinux -or $IsMacOS) { $Env:HOME + "/AtomicRedTeam/atomics" } else { $env:HOMEDRIVE + "\AtomicRedTeam\atomics" }
    $techniqueNumbers = Get-ChildItem $PathToAtomicsFolder -Directory |
    ForEach-Object { $_.BaseName }

    return $techniqueNumbers
}

Register-ArgumentCompleter -CommandName 'Invoke-AtomicTest' -ParameterName 'AtomicTechnique' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    Get-TechniqueNumbers | Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object {
        New-Object System.Management.Automation.CompletionResult $_, $_, 'ParameterValue', "Technique number $_"
    }
}
