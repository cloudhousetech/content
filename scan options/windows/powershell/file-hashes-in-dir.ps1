# Given a path, return hashes for all files (in the directory and subdirectories) of a given type

$path = "C:\files"
$filter = "*.js"

$output = @()
Get-ChildItem -Path $path -Filter $filter -Recurse -File -Name | ForEach-Object {
    $fullpath = "$($path)\$($_)"
    $filepath = Split-Path -Path $fullpath
    $filename = Split-Path -Path $fullpath -Leaf
    $hash = (Get-FileHash $fullpath).Hash
    $f = New-Object –TypeName PSObject -Property @{
        Name = "$($filename)"
        Directory = "$($filepath)"
        Path = "$($fullpath)"
        Checksum = "$($hash)"
    }
    $output += $f
}
$output
