Function Parse-SecPol($CfgFile){
    secedit /export /cfg "$CfgFile" | out-null
    $Result = @()
    $index = 0
    $contents = Get-Content $CfgFile -raw
    [regex]::Matches($contents,"(?<=\[)(.*)(?=\])") | %{
        $obj = New-Object PSObject
        $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $_
        [regex]::Matches($contents,"(?<=\]).*?((?=\[)|(\Z))", [System.Text.RegularExpressions.RegexOptions]::Singleline)[$index] | %{
            $_.value -split "\r\n" | ?{$_.length -gt 0} | %{
                $value = [regex]::Match($_,"(?<=\=).*").value
                $name = [regex]::Match($_,".*(?=\=)").value
                $obj | Add-Member -MemberType NoteProperty -Name $name.tostring().trim() -Value $value.tostring().trim() -ErrorAction SilentlyContinue | out-null
            }
        }
        $Result += $obj
        $index += 1
    }
    return $Result
}
$SecPol = Parse-SecPol -CfgFile C:\LocalSecurityPolicy.cfg
$SecPol

