param (
    [string]$fileName,
    [string]$newFileName,
    [string]$node,
    [string]$pattern,
    [string]$type,
    [string]$ciType
)

$apiKey = "[API_KEY]"
$secretKey = "[SECRET_KEY]"
$headers = @{Authorization = 'Token token="' + $apiKey + $secretKey + '"'}

$hasInserted = $false
$scanURI = "https://qa.upguard.org/api/v2/nodes/" + $node + "/automation_snippet?type=" + $type + "&ci_type=" + $ciType
$result = Invoke-RestMethod -Method "GET" -Uri $scanURI -Headers $headers
$result = $result.Split("`n")

Get-Content($fileName) |
    Foreach-Object {
        if ($_ -match $pattern -and !$hasInserted) {
           echo $result
           $hasInserted = $true
           }
        else {
           echo $_
           }
    } | Set-Content($newFileName)

#Format:
# > .\extract-automation-snippets.ps1 "c:\oldfilename.txt" "c:\newfilename.txt" "node #" "pattern to search for in file"
#   "automation type parameter" "CI type parameter"
