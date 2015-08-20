
# 1. Set the folder path
$folder = "C:\Windows\System32\drivers"

# 2. Specify file extentions
$include_extentions = "all";
#$include_extentions = ".dll", ".config"

$crypto = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
 
foreach($f in Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue) {
    if ($f.PSIsContainer) { continue; }
    try {
        $cast = [System.IO.FileInfo]$f
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
             $version = $f.VersionInfo.FileVersion
             if ($version.length -gt 0) {
                $hashes += $version
                $hashes += " - "
             }
             $hashes += $f.Name
             $hashes += "`r`n" 
         }
    } catch [System.InvalidCastException] {
        #Continue
    } catch [System.Exception] {
        "Error: " + $f.FullName + ": " + $_.Exception.Message
    }
}

$output = "" | Select folder, raw
$output.folder = $folder
$output.raw = $hashes

$output
