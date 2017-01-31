[regex]$regex   = '(?<Name>\S+), Version=(?<Version>\S+), Culture=(?<Culture>\S+), PublicKeyToken=(?<PublicKeyToken>\S+)'
$folder         = "C:\Windows\Assembly"
$gac = @()

foreach($f in Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | where { ! $_.PSIsContainer })
{
    try {
        $obj    = '' | Select Name, Culture, Version, PublicKeyToken
        $a      = [Reflection.Assembly]::LoadFile($f.FullName).FullName
        $fv    = [Diagnostics.FileVersionInfo]::GetVersionInfo($f.FullName).FileVersion
        $result = $a -match $regex
        $subfolder = $f.FullName.Split('\')[3]
        $name = $subfolder + '-' + $matches.Name

        $tempObj = New-Object –TypeName PSObject
        $tempObj | Add-Member -MemberType NoteProperty –Name Name –Value $name
        $tempObj | Add-Member -MemberType NoteProperty –Name Path –Value $f.FullName
        $tempObj | Add-Member -MemberType NoteProperty –Name Culture –Value $matches.Culture
        $tempObj | Add-Member -MemberType NoteProperty –Name Version –Value $matches.Version
        $tempObj | Add-Member -MemberType NoteProperty -Name PublicKeyToken -Value $matches.PublicKeyToken
        $tempObj | Add-Member -MemberType NoteProperty -Name FileVersion -Value $fv
        $tempObj | Add-Member -MemberType NoteProperty -Name SubFolder -Value $subfolder

        $gac += $tempObj
    } catch [System.Exception] {
        $err = "Could not read file " + $f + ": " + $_.Exception.Message
    }
}
$gac
