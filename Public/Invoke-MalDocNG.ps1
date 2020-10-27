# Maldoc Handler
# This function uses COM objects to emulate the creation and execution of malicious office documents

function Invoke-MalDoc($macro_code, $sub_name, $office_version, $office_product, $vba_arguments) {

#Read macrocode from file
    $macro_string = [System.IO.File]::ReadAllText($macro_code)
    
#Variable Replacement
    foreach ($key in $vba_arguments.keys){
        $value = $vba_arguments.$key
        $var_name = "{#$key}"
	$macro_string = $macro_string -replace $var_name, $value
    }
    
    if ($office_product -eq "Word") {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$office_version\Word\Security\" -Name 'AccessVBOM' -Value 1
        
        $word = New-Object -ComObject "Word.Application"
        $doc = $word.Documents.Add()
       
        $word.ActiveDocument.VBProject.VBComponents.Add(1) | Out-Null
        $word.VBE.ActiveVBProject.VBComponents.Item("Module1").CodeModule.AddFromString($macro_string)

        $word.Run($sub_name)
        $doc.Close(0)
    }
    elseif ($office_product -eq "Excel") {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$office_version\Excel\Security\" -Name 'AccessVBOM' -Value 1
        
        $excel = New-Object -ComObject "Excel.Application"
        $excel.Workbooks.Add()
        
        $excel.VBE.ActiveVBProject.VBComponents.Add(1) | Out-Null
        $excel.VBE.ActiveVBProject.VBComponents.Item("Module1").CodeModule.AddFromString($macro_string)
        
        $excel.Run($sub_name)
        $excel.DisplayAlerts = $False
        $excel.Quit()
    }
    else {
        Write-Host -ForegroundColor Red "$office_product not supported"
    }
}
