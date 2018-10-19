# Given a path, return hashes for all files (in the directory and subdirectories) of a given type, grouped by directory name
# Powershell Scan Option Key: Directory

$path = "C:\files"
$include = @(
    "*.html",
    "*.js",
    "*.asp",
    "*.dll",
    "*.aspx",
    "*.config",
    "*.xsl",
    "*.xml",
    "*.json",
    "*.htm",
    "*.xslt",
    "*.properties"
)

$output = @()
$paths = @(gi $path) + @(Get-ChildItem $path -Recurse -Directory -ErrorAction SilentlyContinue | % { $_.FullName })
$paths | ForEach-Object {
    $fullpath = $_
    $dir = New-Object –TypeName PSObject -Property @{
      Directory = "$($fullpath)"
    }
    Get-ChildItem -Path "$($fullpath)" -Include $include -File -Name | ForEach-Object {
      $filepath = "$($fullpath)\$($_)"
      $dir | Add-Member -MemberType NoteProperty -Name $filepath -Value (Get-FileHash $filepath).Hash.ToString()
    }
    $output += $dir
}
$output
