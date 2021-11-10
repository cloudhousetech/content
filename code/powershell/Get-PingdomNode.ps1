<#
.SYNOPSIS
    Scans checks in pingdom for Guardian Script Path (Windows) node type

.PARAMETER APIToken
    Your token for access the pingdom api

.EXAMPLE
.\Get-PingdomNode.ps1 {{password}}

Using the above as the script path in the node configuration and setting the password field with your Pingdom api token will securely scan pingdom checks.
#>

param (
  [Parameter(Mandatory=$true)]
  [string]$APIToken
)

$headers = @{Authorization='Bearer ' + $APIToken}
$response = Invoke-RestMethod 'https://api.pingdom.com/api/3.1/checks' -Headers $headers
 
# grab parts of the resp
$checksArray = $response.checks
$counts = $response.counts

# convert the array to hash using name as key
$checks = @{}
$checksArray | ForEach-Object {
    $ele = $_
    $key = $ele.name.ToString()
    $checks[$key] = $ele
}

# intermediate node for 2 layers
$res = [pscustomobject]@{
    'Pingdom Checks' = $checks
    counts = [pscustomobject]@{all=$counts}
}

ConvertTo-Json $res
