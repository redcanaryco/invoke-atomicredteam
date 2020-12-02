# Maldoc Handler
# This function uses COM objects to emulate the creation and execution of malicious office documents

function Invoke-MalDoc {
    <#
    .SYNOPSIS
    A module to programatically execute Microsoft Word and Exel Documents containing macros.

    .DESCRIPTION
    A module to programatically execute Microsoft Word and Exel Documents containing macros. The module will add a registry key to allow PowerShell to interact with VBA. Use the `-Cleanup` flag to revert this change
    .PARAMETER macroCode
    [Required] The VBA code to be executed. By default, this macro code will be wrapped in a sub routine, called "Test" by default. If you don't want your macro code to be wrapped in a sub routine use the `-noWrap` flag. To specify the subroutine name use the `-sub` parameter.
    .PARAMETER officeVersion
    [Required] The Microsoft Office version to use for executing the document. E.g. "16.0"
    .PARAMETER officeProduct
    [Required] The Microsoft Office application in which to create and execute the macro, either "Word" or "Excel".
    .PARAMETER sub
    [Optional] The name of the subroutine in the macro code to call for execution. Also the name of the subroutine to wrap the supplied `macroCode` in if `noWrap` is not specified.
    .PARAMETER noWrap
    [Optional] A switch that specifies that the supplied `macroCode` should be used as-is and not wrapped in a subroutine.
    
    .EXAMPLE
    C:\PS> Invoke-Maldoc -macroCode "MsgBox `"Hello`"" -officeVersion "16.0" -officeProduct "Word"
    -----------
    Create a macro enabled Microsoft Word Document (using the installed Office version 16.0). The macro code `MsgBox "Hello"` will be wrapped inside of a subroutine call "Test" and then executed.
    
    .EXAMPLE
    C:\PS> Invoke-Maldoc -macroCode "MsgBox `"Hello`"" -officeVersion "15.0" -officeProduct "Excel" -sub "DoIt"
    -----------
    Create a macro enabled Microsoft Excel Document (using the installed Office version 15.0). The macro code `MsgBox "Hello"` will be wrapped inside of a subroutine call "DoIt" and then executed.

    .EXAMPLE
    C:\PS> Invoke-Maldoc -macroCode "Sub Exec()`nMsgBox `"Hello`"`nEnd Sub" -officeVersion "16.0" -officeProduct "Word" -noWrap -sub "Exec"
    -----------
    Create a macro enabled Microsoft Word Document (using the installed Office version 16.0). The macroCode will be unmodified (i.e. not wrapped insided a subroutine) and the "Exec" subroutine will be executed.

    .EXAMPLE
    C:\PS> Invoke-Maldoc -officeVersion "16.0" -officeProduct "Word" -Cleanup
    Remove the Office Security AccessVBOM registry key
#>

    Param(
        [Parameter(Position = 0, Mandatory = $True, ParameterSetName = 'execution')]
        [String]$macroCode,

        [Parameter(Position = 1, Mandatory = $True)]
        [String]$officeVersion,

        [Parameter(Position = 2, Mandatory = $True)]
        [ValidateSet("Word", "Excel")]
        [String]$officeProduct,

        [Parameter(Position = 3, Mandatory = $false, ParameterSetName = 'execution')]
        [String]$sub = "Test",

        [Parameter(Position = 4, Mandatory = $false, ParameterSetName = 'execution')]
        [switch]$noWrap,

        [Parameter(Mandatory = $True, ParameterSetName = 'cleanup')]
        [switch]$Cleanup
    )

    if ($Cleanup) {
        Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Office\$officeVersion\$officeProduct\Security\' -Name 'AccessVBOM' -ErrorAction Ignore
    }
    else {
        if (-not $noWrap) {
            $macroCode = "Sub $sub()`n" + $macroCode + "`nEnd Sub"
        } 
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$officeVersion\$officeProduct\Security\" -Name 'AccessVBOM' -Value 1
        $app = New-Object -ComObject "$officeProduct.Application"
        if ($officeProduct -eq "Word") {
            $null = $app.Documents.Add()
        }
        else {
            $null = $app.Workbooks.Add()
        }
        $null = $app.VBE.ActiveVBProject.VBComponents.Add(1)
        $app.VBE.ActiveVBProject.VBComponents.Item("Module1").CodeModule.AddFromString($macroCode)
        $app.Run($sub)
    }
}