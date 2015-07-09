[regex]$regex   = '(?<Name>\S+), Version=(?<Version>\S+), Culture=(?<Culture>\S+), PublicKeyToken=(?<PublicKeyToken>\S+)'
$folder         = "C:\Windows\Assembly"
$gac            = "PublicKeyToken;   Version; Culture; Name; File Version`r`n"
$gac            += "------------------------------------------------------------`r`n"
[PSCustomObject[]]$collected      = @()
$fileDict     = @{}

foreach($f in Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | where { ! $_.PSIsContainer })
{
    try {
        $obj    = '' | Select Name, Culture, Version, PublicKeyToken
        $a      = [Reflection.Assembly]::LoadFile($f.FullName).FullName
        $fv    = [Diagnostics.FileVersionInfo]::GetVersionInfo($f.FullName).FileVersion
        $result = $a -match $regex
                
        $tempObj = New-Object –TypeName PSObject
        $tempObj | Add-Member -MemberType NoteProperty –Name Name –Value $matches.Name
        $tempObj | Add-Member -MemberType NoteProperty –Name Culture –Value $matches.Culture
        $tempObj | Add-Member -MemberType NoteProperty –Name Version –Value $matches.Version
        $tempObj | Add-Member -MemberType NoteProperty -Name PublicKeyToken -Value $matches.PublicKeyToken
        $tempObj | Add-Member -MemberType NoteProperty -Name FileVersion -Value $fv
        
        $subfolder = $f.FullName.Split('\')[3]
        if($fileDict.ContainsKey($folder + "\" + $subfolder)) {
            $fileDict[$folder + "\" + $subfolder] += $tempObj
        } else {
            $fileDict[$folder + "\" + $subfolder] = @($tempObj)
        }
                
    } catch [System.Exception] {
        $err = "Could not read file " + $f + ": " + $_.Exception.Message
    }
}

foreach($g in $fileDict.GetEnumerator() | Sort-Object { $_.Key }) {

    $collected = $fileDict[$g.Key] | Sort-Object Name
    $gac += $g.Key
    $gac += "`r`n"
    foreach($line in $collected) {
        $gac += "#" + $line.PublicKeyToken + "; " + $line.Version + "; " + $line.Culture + "; " + $line.Name + "; " + $line.FileVersion + "`r`n"
    }
}

$output = "" | Select folder, raw
$output.folder = $folder
$output.raw    = $gac
$output
