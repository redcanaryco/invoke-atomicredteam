function Write-KeyValue ($key, $value) {
    Write-Host -ForegroundColor Cyan -NoNewline $key
    $split = $value -split "(#{[a-z-_A-Z]*})"
    foreach ($s in $split) {
        if ($s -match "(#{[a-z-_A-Z]*})") {
            Write-Host -ForegroundColor Red -NoNewline $s
        }
        else {
            Write-Host -ForegroundColor Green -NoNewline $s
        }
    }
    Write-Host ""
}
