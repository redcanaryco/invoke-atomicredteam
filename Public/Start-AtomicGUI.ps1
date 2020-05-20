function Start-AtomicGUI {
    # Install-Module -Name UniversalDashboard.Community -RequiredVersion 2.9.0 -scope CurrentUser
    Get-UDDashboard | Stop-UDDashboard
    $port = 8888

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
            New-UDSelect -Label "Type" -Option {
                New-UDSelectOption -Name "Path" -Value "path"
                New-UDSelectOption -Name "String" -Value "string"
                New-UDSelectOption -Name "Url" -Value "url"
                New-UDSelectOption -Name "Integer" -Value "int"
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
        -Variable @("InputArgCards", "depCards") `
        -Module @("..\Invoke-AtomicRedTeam.psd1")

    ############## Static Definitions
    $supportedPlatforms = New-UDLayout -Columns 4 {
        New-UDElement -Tag Label -Attributes @{ style = @{"font-size" = "15px" } } -Content { "Supported Platforms:" } 
        New-UDCheckbox -FilledIn -Label "Windows" -Checked -Id spWindows
        New-UDCheckbox -FilledIn -Label "Linux" -Id spLinux
        New-UDCheckbox -FilledIn -Label "macOS"-Id spMacOS
    }

    $executorRow = New-UDLayout -Columns 4 {
        New-UDSelectX 'executorSelector' "Executor for Attack Commands"
        New-UDCheckbox -FilledIn -Label "Requires Elevation to Execute Successfully?" 
    }

    $genarateYamlButton = New-UDRow -Columns {
        New-UDColumn -Size 8 -Content { }
        New-UDColumn -Size 4 -Content {
            New-UDButton -Text "Generate Test Definition YAML" -OnClick (
                New-UDEndpoint -Endpoint {
                    Show-UDModal -Header {
                        New-UDHeading -Size 3 -Text "Test Definition YAML"
                    } -Content {
                        new-udrow -endpoint {
                            $InputArg1 = New-AtomicTestInputArgument -Name filename -Description 'location of the payload' -Type Path -Default 'PathToAtomicsFolder\T1118\src\T1118.dll'
                            $InputArg2 = New-AtomicTestInputArgument -Name source -Description 'location of the source code to compile' -Type Path -Default 'PathToAtomicsFolder\T1118\src\T1118.cs'
                            $testName = (Get-UDElement -Id atomicName).Attributes['value']
                            $testDesc = (Get-UDElement -Id atomicDescription).Attributes['value']
                            $platforms = @()
                            if ((Get-UDElement -Id spWindows).Attributes['checked']) { $platforms += "Windows" }
                            if ((Get-UDElement -Id spLinux).Attributes['checked']) { $platforms += "Linux" }
                            if ((Get-UDElement -Id spMacOS).Attributes['checked']) { $platforms += "macOS" }
                            $attackCommands = (Get-UDElement -Id attackCommands).Attributes['value']
                            $executor = (Get-UDElement -Id executorSelector).Attributes['value']
                            if ("" -eq $executor) { $executor = "PowerShell" }
                            # $NewInputArg = [AtomicInputArgument]::new()
                            $AtomicTest = New-AtomicTest -Name $testName -Description $testDesc -SupportedPlatforms $platforms -InputArguments $InputArg1, $InputArg2 -ExecutorType $executor -ExecutorCommand $attackCommands                                                    
                            $message = $AtomicTest | ConvertTo-Yaml
                            New-UDElement -Tag pre -Content { $message }
                        } 
                    }
                }
            )   
        }
    }

    ############## End Static Definitions

    ############## The Dashboard
    $db = New-UDDashboard -Title "Atomic Test Creation" -EndpointInitialization $ei -Content {

        New-UDCard -Id "mainCard" -Content {
            New-UDCard -Content {
                New-UDTextBoxX 'atomicName' "Atomic Test Name"
                New-UDTextAreaX "atomicDescription" "Atomic Test Description"
                $supportedPlatforms
                # Attack Commands
                New-UDTextAreaX "attackCommands" "Attack Commands"
                $executorRow
                New-UDTextAreaX "cleanupCommands" "Cleanup Commands (Optional)"
                # Generate Test Definition Yaml Button
                $genarateYamlButton  
            }

            # input args
            New-UDCard -Id "inputCard" -Endpoint {
                New-UDButton -Text "Add Input Argument (Optional)" -OnClick (
                    New-UDEndpoint -Endpoint {
                        Add-UDElement -ParentId "inputCard" -Content {
                            New-InputArgCard
                        }
                    }
                )
            }

            # prereqs
            New-UDCard -Id "depCard" -Endpoint {
                New-UDButton -Text "Add Prerequisite (Optional)" -OnClick (
                    New-UDEndpoint -Endpoint {
                        Add-UDElement -ParentId "depCard" -Content {
                            if ($null -eq (Get-UDElement -Id preReqEx)) {
                                New-UDLayout -columns 4 {
                                    New-UDSelectX 'preReqEx' "Executor for Prereq Commands" }
                            }
                            New-depCard
                        }
                    }
                )
            }   
        }

        # button to fill form with test data for development purposes
        New-UDButton -Text "Fill Test Data" -OnClick (
            New-UDEndpoint -Endpoint {
                Add-UDElement -ParentId "depCard" -Content {
                    Set-UDElement -Id atomicName -Attributes @{value = "My new atomic" }
                    Set-UDElement -Id atomicDescription -Attributes @{value = "This is the atomic description" }
                    Set-UDElement -Id attackCommands -Attributes @{value = "echo this`necho that" }
                    Add-UDElement -ParentId "inputCard" -Content {
                        New-InputArgCard
                    }
                    Add-UDElement -ParentId "depCard" -Content {
                        if ($null -eq (Get-UDElement -Id preReqEx)) {
                            New-UDLayout -columns 4 {
                                New-UDSelectX 'preReqEx' "Executor for Prereq Commands" }
                        }
                        New-depCard
                    }
                    Start-Sleep 1
                    # InputArgs
                    $cardNumber = 1
                    Set-UDElement -Id "InputArgCard$cardNumber-InputArgName" -Attributes @{value = "inputArg1" }
                    Set-UDElement -Id "InputArgCard$cardNumber-InputArgDescription" -Attributes @{value = "InputArg1 description" }        
                    Set-UDElement -Id "InputArgCard$cardNumber-InputArgDefault" -Attributes @{value = "this is the default value" }        
            
                    # dependencies
                    Set-UDElement -Id "depCard$cardNumber-depDescription" -Attributes @{value = "This file must exist" }
                    Set-UDElement -Id "depCard$cardNumber-prereqCommand" -Attributes @{value = "if (this) then that" }       
                    Set-UDElement -Id "depCard$cardNumber-getPrereqCommand" -Attributes @{value = "iwr" }       
            
                }
            }
        )
     
    }
    ############## End of the Dashboard

    Start-UDDashboard -port $port -Dashboard $db #-AutoReload
    start-process http://localhost:$port
}