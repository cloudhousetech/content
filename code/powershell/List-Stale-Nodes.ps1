# List all nodes that haven't been scanned in the past 30 days
# Usage: List-Stale-Nodes.ps1 -Url https://upguard.url -ApiKey 12345 -SecretKey 12345 -Days 30

param (
  [Parameter(Mandatory=$true)][string]$Url,
  # Get the API and secret keys: https://support.upguard.com/upguard/using-the-api.html#authorization-header
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [Parameter(Mandatory=$true)][string]$SecretKey,
  [Int]$Days = 30
)

# Perform an API request and return the result as a Powershell object
# If you need to handle pagination, you can provide the Paginate switch with a CombineAttribute if you
#   need to combine pages on a specific attribute
# For example, the /api/v2/nodes.json endpoint returns a list so pages can be combined and return a list
#   just by passing the Paginate switch
# Alternatively, the /api/v2/diffs.json endpoint returns statistics along with a "diff_items" attribute
#     which contains the list of diffs. Passing the Paginate switch with "diff_items" for CombineAttribute
#     will return a usable list
function UpGuard-WebRequest
{
    param
    (
      [string]$Method = 'Get',
      [string]$Endpoint,
      [string]$ApiKey,
      [string]$SecretKey,
      [hashtable]$Body = @{},
      [switch]$Paginate,
      [string]$CombineAttribute = "" # To paginate, provide the attribute to combine multiple results
    )

    # Handle very large JSON responses (such as scan data)
    # [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    # $jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    # $jsonserial.MaxJsonLength  = 67108864

    $headers = @{'Authorization' = "Token token=""$($ApiKey)$($SecretKey)"""}
    if ($Paginate) {
      $result = @()
      if ($Body.Keys -notcontains "page") { $Body.page = 1 }
      if ($Body.Keys -notcontains "per_page") { $Body.per_page = 50 }
      while ($true) {
        $new = Invoke-WebRequest -Method $Method -Uri $Endpoint -Headers $headers -Body $Body -ContentType "application/json"
        if ($new.StatusCode > 400){throw [System.Exception] "$($new.StatusCode.ToString()) $($new.StatusDescription)"}
        $new = ConvertFrom-Json $new.Content

        if ($CombineAttribute -ne "") {
          $new = $new | Select -ExpandProperty $CombineAttribute

          $result += $new
          if ([int]$new.Count -lt [int]$Body.per_page) { return $result}
        }
        else {
          # No CombineAttribute was provided
          $result += $new
          if ([int]$new.Count -lt [int]$Body.per_page) { return $result }
        }
        $Body.page = [int]$Body.page + 1
      }
    }
    if ($Method -in "Get","Delete"){$req = Invoke-WebRequest -Method $Method -Uri $Endpoint -Headers $headers -ContentType "application/json"}
    else{$req = Invoke-WebRequest -Method $Method -Uri $Endpoint -Headers $headers -Body $Body -ContentType "application/json"}
    if ($req)
    {
      if ($req.StatusCode > 400){throw [System.Exception] "$($req.StatusCode.ToString()) $($req.StatusDescription)"}
      # else{return $jsonserial.DeserializeObject($req.Content)}
      else { return ConvertFrom-Json $req.Content }
    }
}

# [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::SSL3 -bor [System.Net.SecurityProtocolType]::TLS;

# Get a list of all nodes in UpGuard
$Nodes = UpGuard-WebRequest -Endpoint "$($Url)/api/v2/nodes.json" -ApiKey $ApiKey -SecretKey $SecretKey -Paginate
Write-Output "Found $($Nodes.Count) total nodes in UpGuard"
Write-Output "---"
Write-Output "Stale nodes (with last scanned date):"
$CurrentDate = Get-Date
$DateThreshold = $CurrentDate.AddDays(-($Days))
Foreach ($Node in $Nodes)
{
  # Look at the last successful scan
  $LastScan = UpGuard-WebRequest -EndPoint "$($Url)/api/v2/nodes/$($Node.id)/last_successful_scan.json" -ApiKey $ApiKey -SecretKey $SecretKey
  If ($LastScan.created_at -lt $DateThreshold) {
    Write-Output "  - $($Node.name) $($LastScan.created_at)"
  }
}
Write-Output "Done!"
