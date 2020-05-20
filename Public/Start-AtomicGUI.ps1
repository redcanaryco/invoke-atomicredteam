
# Install-Module -Name UniversalDashboard.Community -RequiredVersion 2.9.0 -scope CurrentUser
Get-UDDashboard | Stop-UDDashboard
$port = 8888

############## Function Definitions Made Available to EndPoints
function New-UDTextAreaX ($ID, $PlaceHolder) {
    New-UDElement -Tag div -Attributes @{class = "input-field col" } -Content {
        New-UDElement -Tag "textarea" -Attributes @{ id = $ID; class = "materialize-textarea ud-input" }
        New-UDElement -Tag Label -Attributes @{for = $ID } -Content { $PlaceHolder }
    }
}

function New-UDTextBoxX ($ID, $PlaceHolder) {
    New-UDElement -Tag div -Attributes @{class = "input-field col" } -Content {
        New-UDElement -Tag "input" -Attributes @{ id = $ID; class = "ud-input"; type = "text" }
        New-UDElement -Tag Label -Attributes @{for = $ID } -Content { $PlaceHolder }
    }
}

$InputArgCards = @{ }
function New-InputArgCard {
    $cardNumber = $InputArgCards.count + 1
    $newCard = New-UDCard -ID "InputArgCard$cardNumber" -Content {
        New-UDTextBoxX "InputArgName" "Input Argument Name"
        New-UDTextAreaX "InputArgDescription" "Description"        
        New-UDTextBoxX "InputArgDefault" "Default Value"        
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
        New-UDTextBoxX "depDescription" "Prereq Description"
        New-UDTextAreaX "prereqCommand" "Check prereqs Command"        
        New-UDTextAreaX "getPrereqCommand" "Get Prereqs Command"        
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
        New-UDSelectOption -Name "PowerShell" -Value "powershell"
        New-UDSelectOption -Name "Command Prompt" -Value "command_prompt"
        New-UDSelectOption -Name "Bash" -Value "bash"
        New-UDSelectOption -Name "Sh" -Value "sh"
    }
}

############## End Function Definitions Made Available to EndPoints

# EndpointInitialization defining which methods and variables will be available for use within an endpoint
$ei = New-UDEndpointInitialization `
    -Function @("New-InputArgCard", "New-depCard", "New-UDTextAreaX", "New-UDTextBoxX", "New-UDSelectX") `
    -Variable @("InputArgCards", "depCards")

############## Static Definitions
$supportedPlatforms = New-UDLayout -Columns 4 {
    New-UDElement -Tag Label -Attributes @{ style = @{"font-size" = "15px" } } -Content { "Supported Platforms:" } 
    New-UDCheckbox -FilledIn -Label "Windows" -Checked
    New-UDCheckbox -FilledIn -Label "Linux" 
    New-UDCheckbox -FilledIn -Label "macOS"
}

$executorRow = New-UDLayout -Columns 4 {
    New-UDSelectX 'executorSelector' "Executor for Attack Commands"
    New-UDCheckbox -FilledIn -Label "Requires Elevation to Execute Successfully?" 
}

$genarateYamlButton = New-UDRow -Columns {
    New-UDColumn -Size 8 -Content { }
    New-UDColumn -Size 4 -Content {
        New-UDButton -Text "Generate Test Definition YAML"  -OnClick (
            New-UDEndpoint -Endpoint {
                Show-UDModal -Content { "hi" }
            }
        )   
    }
}

############## End Static Definitions

############## The Dashboard
$db = New-UDDashboard -Title "Atomic Test Creation" -EndpointInitialization $ei -Content {

    New-UDCard -Id "mainCard" -Content {
        New-UDCard -Content {
            New-UDTextBoxX "atomicName" "Atomic Test Name"
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
            New-UDButton -Text "Add Input Argument (Optional)"  -OnClick (
                New-UDEndpoint -Endpoint {
                    Add-UDElement -ParentId "inputCard" -Content {
                        New-InputArgCard
                    }
                }
            )
        }

        # prereqs
        New-UDCard -Id "depCard" -Endpoint {
            New-UDButton -Text "Add Prerequisite (Optional)"  -OnClick (
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


    New-UDButton -Text "Show Modal" -OnClick {
        Show-UDModal -Header {
            New-UDHeading -Size 3 -Text "Test Definition YAML"
        } -Content {
            new-udcard -endpoint {
                New-UDElement -Tag pre -Content { "111`n   222`n      333" }
            }
        }
    }
      
}
############## End of the Dashboard

Start-UDDashboard -port $port -Dashboard $db #-AutoReload
start-process http://localhost:$port