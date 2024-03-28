function Invoke-FetchFromZip {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $zipUrl,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $targetFilter, # files that match this filter will be copied to the destinationPath, retaining their folder path from the zip
        [Parameter(Mandatory = $true, Position = 2)]
        [String]
        $destinationPath
    )

    # load ZIP methods
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression') | Out-Null

    # read zip archive into memory
    $ms = New-Object IO.MemoryStream
    [Net.ServicePointManager]::SecurityProtocol = ([Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12)
    (New-Object System.Net.WebClient).OpenRead($zipUrl).copyto($ms)
    $Zip = New-Object System.IO.Compression.ZipArchive($ms)

    # ensure the output folder exists
    $parent = split-path $destinationPath
    $exists = Test-Path -Path $parent
    if ($exists -eq $false) {
        $null = New-Item -Path $destinationPath -ItemType Directory -Force
    }

    # find all files in ZIP that match the filter (i.e. file extension)
    $zip.Entries |
    Where-Object {
            ($_.FullName -like $targetFilter)
    } |
    ForEach-Object {
        # extract the selected items from the ZIP archive
        # and copy them to the out folder
        $dstDir = Join-Path $destinationPath ($_.FullName | split-path | split-path -Leaf)
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, (Join-Path $dstDir $_.Name), $true)
    }
    $zip.Dispose()
}
