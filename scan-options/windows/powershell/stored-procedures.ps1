# Return a hash for each stored procedure for a given database
# Modify the $databases array to specify the databases to query
# Note: This can take a while, you will likely need to increase the test timeout

# Description: MS SQL Stored Procedures
# Key Name: Name

$databases = @("tempdb")

$result = New-Object –TypeName PSObject
Import-Module “sqlps” -DisableNameChecking
$dbs = Get-ChildItem -FORCE SQLSERVER:\SQL\localhost\DEFAULT\Databases
ForEach($db in $dbs)
{
    if($db.Name -in $databases)
    {
        $procedures = @{}
        ForEach($sp in $db.StoredProcedures)
        {
            $name = "$($sp.Schema).$($sp.Name)"
            if($sp.TextBody){$text = $sp.TextBody.ToString()}else{$text = ""}

            # Convert to hash
            $hash = New-Object System.Text.StringBuilder
            [System.Security.Cryptography.HashAlgorithm]::Create("MD5").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))|%{[Void]$hash.Append($_.ToString("x2"))}

            $procedures.Add($name, $hash.ToString())
        }
        $result | Add-Member -MemberType NoteProperty –Name $db.Name –Value $procedures
    }
}
$result
