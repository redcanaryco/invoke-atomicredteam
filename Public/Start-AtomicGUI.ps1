function Start-AtomicGUI {
    param (
        [Int] $port = 8487
    )
    # Install-Module UniversalDashboard if not already installed
    $UDcommunityInstalled = Get-InstalledModule -Name "UniversalDashboard.Community" -ErrorAction:SilentlyContinue
    $UDinstalled = Get-InstalledModule -Name "UniversalDashboard" -ErrorAction:SilentlyContinue
    if (-not $UDcommunityInstalled -and -not $UDinstalled) {
        Write-Host "Installing UniversalDashboard.Community"
        Install-Module -Name UniversalDashboard.Community -Scope CurrentUser -Force
    }

    ############## Function Definitions Made Available to EndPoints
    function New-UDTextAreaX ($ID, $PlaceHolder) {
        New-UDElement -Tag div -Attributes @{class = "input-field col" } -Content {
            New-UDElement -Tag "textarea" -id  $ID -Attributes @{ class = "materialize-textarea ud-input" }
            New-UDElement -Tag Label -Attributes @{for = $ID } -Content { $PlaceHolder }
        }
    }

    function New-UDTextBoxX ($ID, $PlaceHolder) {
        New-UDElement -Tag div -Attributes @{class = "input-field col" } -Content {
            New-UDElement -Tag "input" -id $ID -Attributes @{ class = "ud-input"; type = "text" }
            New-UDElement -Tag Label -Attributes @{for = $ID } -Content { $PlaceHolder }
        }
    }

    $InputArgCards = @{ }
    function New-InputArgCard {
        $cardNumber = $InputArgCards.count + 1
        $newCard = New-UDCard -ID "InputArgCard$cardNumber" -Content {
            New-UDTextBoxX "InputArgCard$cardNumber-InputArgName" "Input Argument Name"
            New-UDTextAreaX "InputArgCard$cardNumber-InputArgDescription" "Description"
            New-UDTextBoxX "InputArgCard$cardNumber-InputArgDefault" "Default Value"
            New-UDLayout -columns 4 {
                New-UDSelect -ID "InputArgCard$cardNumber-InputArgType" -Label "Type" -Option {
                    New-UDSelectOption -Name "Path" -Value "path"
                    New-UDSelectOption -Name "String" -Value "string"
                    New-UDSelectOption -Name "Url" -Value "url"
                    New-UDSelectOption -Name "Integer" -Value "integer"
                }
            }
            New-UDButton -Text "Remove this Input Argument"  -OnClick (
                New-UDEndpoint -Endpoint {
                    Remove-UDElement -Id "InputArgCard$cardNumber"
                    $inputArgCards["InputArgCard$cardNumber"] = $true
                } -ArgumentList @($cardNumber, $inputArgCards)
            )
        }
        $InputArgCards.Add("InputArgCard$cardNumber", $false) | Out-Null
        $newCard
    }

    $depCards = @{ }
    function New-depCard {
        $cardNumber = $depCards.count + 1
        $newCard = New-UDCard -ID "depCard$cardNumber" -Content {
            New-UDTextBoxX "depCard$cardNumber-depDescription" "Prereq Description"
            New-UDTextAreaX "depCard$cardNumber-prereqCommand" "Check prereqs Command"
            New-UDTextAreaX "depCard$cardNumber-getPrereqCommand" "Get Prereqs Command"
            New-UDButton -Text "Remove this Prereq"  -OnClick (
                New-UDEndpoint -Endpoint {
                    Remove-UDElement -Id "depCard$cardNumber"
                    $depCards["depCard$cardNumber"] = $true
                } -ArgumentList @($cardNumber, $depCards)
            )
        }
        $depCards.Add("depCard$cardNumber", $false) | Out-Null
        $newCard
    }

    function New-UDSelectX ($Id, $Label) {
        New-UDSelect -Label $Label -Id $Id -Option {
            New-UDSelectOption -Name "PowerShell" -Value "PowerShell" -Selected
            New-UDSelectOption -Name "Command Prompt" -Value "CommandPrompt"
            New-UDSelectOption -Name "Bash" -Value "Bash"
            New-UDSelectOption -Name "Sh" -Value "Sh"
        }
    }

    ############## End Function Definitions Made Available to EndPoints

    # EndpointInitialization defining which methods, modules, and variables will be available for use within an endpoint
    $ei = New-UDEndpointInitialization `
        -Function @("New-InputArgCard", "New-depCard", "New-UDTextAreaX", "New-UDTextBoxX", "New-UDSelectX") `
        -Variable @("InputArgCards", "depCards", "yaml") `
        -Module @("..\Invoke-AtomicRedTeam.psd1")

    ############## EndPoint (ep) Definitions: Dynamic code called to generate content for an element or perfrom onClick actions
    $BuildAndDisplayYamlScriptBlock = {
        $testName = (Get-UDElement -Id atomicName).Attributes['value']
        $testDesc = (Get-UDElement -Id atomicDescription).Attributes['value']
        $platforms = @()
        if ((Get-UDElement -Id spWindows).Attributes['checked']) { $platforms += "Windows" }
        if ((Get-UDElement -Id spLinux).Attributes['checked']) { $platforms += "Linux" }
        if ((Get-UDElement -Id spMacOS).Attributes['checked']) { $platforms += "macOS" }
        $attackCommands = (Get-UDElement -Id attackCommands).Attributes['value']
        $executor = (Get-UDElement -Id executorSelector).Attributes['value']
        $elevationRequired = (Get-UDElement -Id elevationRequired).Attributes['checked']
        $cleanupCommands = (Get-UDElement -Id cleanupCommands).Attributes['value']
        if ("" -eq $executor) { $executor = "PowerShell" }
        # input args
        $inputArgs = @()
        $InputArgCards.GetEnumerator() | ForEach-Object {
            if ($_.Value -eq $false) {
                # this was not deleted
                $prefix = $_.key
                $InputArgName = (Get-UDElement -Id "$prefix-InputArgName").Attributes['value']
                $InputArgDescription = (Get-UDElement -Id "$prefix-InputArgDescription").Attributes['value']
                $InputArgDefault = (Get-UDElement -Id "$prefix-InputArgDefault").Attributes['value']
                $InputArgType = (Get-UDElement -Id "$prefix-InputArgType").Attributes['value']
                if ("" -eq $InputArgType) { $InputArgType = "String" }
                $NewInputArg = New-AtomicTestInputArgument -Name $InputArgName -Description $InputArgDescription -Type $InputArgType -Default $InputArgDefault -WarningVariable +warnings
                $inputArgs += $NewInputArg
            }
        }
        # dependencies
        $dependencies = @()
        $preReqEx = ""
        $depCards.GetEnumerator() | ForEach-Object {
            if ($_.Value -eq $false) {
                # a value of true means the card was deleted, so only add dependencies from non-deleted cards
                $prefix = $_.key
                $depDescription = (Get-UDElement -Id "$prefix-depDescription").Attributes['value']
                $prereqCommand = (Get-UDElement -Id "$prefix-prereqCommand").Attributes['value']
                $getPrereqCommand = (Get-UDElement -Id "$prefix-getPrereqCommand").Attributes['value']
                $preReqEx = (Get-UDElement -Id "preReqEx").Attributes['value']
                if ("" -eq $preReqEx) { $preReqEx = "PowerShell" }
                $NewDep = New-AtomicTestDependency -Description $depDescription -PrereqCommand $prereqCommand -GetPrereqCommand $getPrereqCommand -WarningVariable +warnings
                $dependencies += $NewDep
            }
        }
        $depParams = @{ }
        if ($dependencies.count -gt 0) {
            $depParams.add("DependencyExecutorType", $preReqEx)
            $depParams.add("Dependencies", $dependencies)
        }
        if (($cleanupCommands -ne "") -and ($null -ne $cleanupCommands)) { $depParams.add("ExecutorCleanupCommand", $cleanupCommands) }
        $depParams.add("ExecutorElevationRequired", $elevationRequired)

        $AtomicTest = New-AtomicTest -Name $testName -Description $testDesc -SupportedPlatforms $platforms -InputArguments $inputArgs -ExecutorType $executor -ExecutorCommand $attackCommands -WarningVariable +warnings @depParams
        $yaml = ($AtomicTest | ConvertTo-Yaml) -replace "^", "- " -replace "`n", "`n  "
        foreach ($warning in $warnings) { Show-UDToast $warning -BackgroundColor LightYellow -Duration 10000 }
        New-UDElement -ID yaml -Tag pre -Content { $yaml }
    }

    $epYamlModal = New-UDEndpoint -Endpoint {
        Show-UDModal -Header { New-UDHeading -Size 3 -Text "Test Definition YAML" } -Content {
            new-udrow -endpoint $BuildAndDisplayYamlScriptBlock
            # Left arrow button (decrease indentation)
            New-UDButton -Icon arrow_circle_left -OnClick (
                New-UDEndpoint -Endpoint {
                    $yaml = (Get-UDElement -Id "yaml").Content[0]
                    if (-not $yaml.startsWith("- ")) {
                        Set-UDElement -Id "yaml" -Content {
                            $yaml -replace "^  ", "" -replace "`n  ", "`n"
                        }
                    }
                }
            )
            # Right arrow button (increase indentation)
            New-UDButton -Icon arrow_circle_right -OnClick (
                New-UDEndpoint -Endpoint {
                    $yaml = (Get-UDElement -Id "yaml").Content[0]
                    Set-UDElement -Id "yaml" -Content {
                        $yaml -replace "^", "  " -replace "`n", "`n  "
                    }
                }
            )
            # Copy Yaml to clipboard
            New-UDButton -Text "Copy" -OnClick (
                New-UDEndpoint -Endpoint {
                    $yaml = (Get-UDElement -Id "yaml").Content[0]
                    Set-UDClipboard -Data $yaml
                    Show-UDToast -Message "Copied YAML to the Clipboard" -BackgroundColor YellowGreen
                }
            )
        }
    }

    $epFillTestData = New-UDEndpoint -Endpoint {
        Add-UDElement -ParentId "inputCard" -Content { New-InputArgCard }
        Add-UDElement -ParentId "depCard"   -Content { New-depCard }
        Start-Sleep 1
        Set-UDElement -Id atomicName -Attributes @{value = "My new atomic" }
        Set-UDElement -Id atomicDescription -Attributes @{value = "This is the atomic description" }
        Set-UDElement -Id attackCommands -Attributes @{value = "echo this`necho that" }
        Set-UDElement -Id cleanupCommands -Attributes @{value = "cleanup commands here`nand here..." }
        # InputArgs
        $cardNumber = 1
        Set-UDElement -Id "InputArgCard$cardNumber-InputArgName" -Attributes @{value = "input_arg_1" }
        Set-UDElement -Id "InputArgCard$cardNumber-InputArgDescription" -Attributes @{value = "InputArg1 description" }
        Set-UDElement -Id "InputArgCard$cardNumber-InputArgDefault" -Attributes @{value = "this is the default value" }
        # dependencies
        Set-UDElement -Id "depCard$cardNumber-depDescription" -Attributes @{value = "This file must exist" }
        Set-UDElement -Id "depCard$cardNumber-prereqCommand" -Attributes @{value = "if (this) then that" }
        Set-UDElement -Id "depCard$cardNumber-getPrereqCommand" -Attributes @{value = "iwr" }

    }
    ############## End EndPoint (ep) Definitions

    ############## Static Definitions
    $supportedPlatforms = New-UDLayout -Columns 4 {
        New-UDElement -Tag Label -Attributes @{ style = @{"font-size" = "15px" } } -Content { "Supported Platforms:" }
        New-UDCheckbox -FilledIn -Label "Windows" -Checked -Id spWindows
        New-UDCheckbox -FilledIn -Label "Linux" -Id spLinux
        New-UDCheckbox -FilledIn -Label "macOS"-Id spMacOS
    }

    $executorRow = New-UDLayout -Columns 4 {
        New-UDSelectX 'executorSelector' "Executor for Attack Commands"
        New-UDCheckbox -ID elevationRequired -FilledIn -Label "Requires Elevation to Execute Successfully?"
    }

    $genarateYamlButton = New-UDRow -Columns {
        New-UDColumn -Size 8 -Content { }
        New-UDColumn -Size 4 -Content {
            New-UDButton -Text "Generate Test Definition YAML" -OnClick ( $epYamlModal )
        }
    }

    ############## End Static Definitions

    ############## The Dashboard
    $idleTimeOut = New-TimeSpan -Minutes 10080
    $db = New-UDDashboard -Title "Atomic Test Creation" -IdleTimeout $idleTimeOut -EndpointInitialization $ei -Content {
        New-UDCard -Id "mainCard" -Content {
            New-UDCard -Content {
                New-UDTextBoxX 'atomicName' "Atomic Test Name"
                New-UDTextAreaX "atomicDescription" "Atomic Test Description"
                $supportedPlatforms
                New-UDTextAreaX "attackCommands" "Attack Commands"
                $executorRow
                New-UDTextAreaX "cleanupCommands" "Cleanup Commands (Optional)"
                $genarateYamlButton
            }

            # input args
            New-UDCard -Id "inputCard" -Endpoint {
                New-UDButton -Text "Add Input Argument (Optional)" -OnClick (
                    New-UDEndpoint -Endpoint { Add-UDElement -ParentId "inputCard" -Content { New-InputArgCard } }
                )
            }

            # prereqs
            New-UDCard -Id "depCard" -Endpoint {
                New-UDLayout -columns 4 {
                    New-UDButton -Text "Add Prerequisite (Optional)" -OnClick (
                        New-UDEndpoint -Endpoint { Add-UDElement -ParentId "depCard" -Content { New-depCard } }
                    )
                    New-UDSelectX 'preReqEx' "Executor for Prereq Commands"
                }
            }
        }

        # button to fill form with test data for development purposes
        if ($false) { New-UDButton -Text "Fill Test Data" -OnClick ( $epFillTestData ) }
    }
    ############## End of the Dashboard

    Stop-AtomicGUI
    Start-UDDashboard -port $port -Dashboard $db -Name "AtomicGUI" -ListenAddress 127.0.0.1
    start-process http://localhost:$port
}

function Stop-AtomicGUI {
    Get-UDDashboard -Name 'AtomicGUI' | Stop-UDDashboard
    Write-Host "Stopped all AtomicGUI Dashboards"
}
