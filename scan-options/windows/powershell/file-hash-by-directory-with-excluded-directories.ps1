# Given a path, return hashes for all files (in the directory and subdirectories) of a given type

$path = "C:\files"
# Filetypes that should be returned in the scan
$includeFiles = @(
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
# Exclude directories with regular expressions. At least one exclude is required for the script to work
# Directories with backslashes will need to be escaped as \\
$excludeDirRegex = @(
    "C:\\files\\AddLifecycle\\ApproveData.*"
    ".*ignore.*"
)

$output = @()
$paths = @(gi $path | % { $_.FullName }) + @(Get-ChildItem $path -Recurse -Directory -ErrorAction SilentlyContinue | Where { $_.FullName -notmatch ( $excludeDirRegex -join '|' ) } | % { $_.FullName })
$paths | ForEach-Object {
    $fullpath = $_
    $dir = New-Object –TypeName PSObject -Property @{
      Directory = "$($fullpath)"
    }
    Get-ChildItem -Path "$($fullpath)" -Include $includeFiles -File -Name | ForEach-Object {
      $filepath = "$($fullpath)\$($_)"
      $dir | Add-Member -MemberType NoteProperty -Name $filepath -Value (Get-FileHash $filepath).Hash.ToString()
    }
    $output += $dir
}
$output
