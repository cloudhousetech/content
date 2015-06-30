
# 1. Set the folder path
$folder = "C:\Windows\System32\drivers"

# 2. Specify file extentions
$include_extentions = "all";
#$include_extentions = ".dll", ".config"

$crypto = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
 
foreach($f in Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | where { ! $_.PSIsContainer }) {
    try {
        $extension = $f.Extension
        if ($include_extentions -contains $extension -or $include_extentions -contains "all" ) {
             $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
             $hash = [System.BitConverter]::ToString($crypto.ComputeHash($bytes)) 
 
             if ($f.DirectoryName -ne $last_subfolder) {
                 $hashes += "# "
                 $hashes += $f.DirectoryName
                 $hashes += "`r`n"
                 $last_subfolder = $f.DirectoryName
             }
             $hashes += $hash.Replace('-','').ToLower() 
             $hashes += ": "
             $version = (Get-Item $f.FullName).VersionInfo.FileVersion
             $hashes += $version
             $hashes += " - "
             $hashes += $f.Name
             $hashes += "`r`n" 
         }
    } catch [System.Exception] {
        err = "Could not read file " + $f + ": " + $_.Exception.Message
    }
}

$output = "" | Select folder, raw
$output.folder = $folder
$output.raw = $hashes

$output
