# Retrieve a list of diffs detected by UpGuard and consolidate those diffs
#   by CI path and node
#
# Required Parameters:
# * ApiKey: UpGuard org's API key
# * SecretKey: UpGuard org's API secret key
# * Url: UpGuard instance URL including https (ex: https://upguard.company.com)
# * StartDate: Beginning point to look for diffs, format YYYY-mm-dd
# * EndDate: End point to look for diffs, format YYYY-mm-dd

# Optional Parameters
# * EnvironmentID: ID of environment to retrieve diffs. Omit this to return diffs for all environments

param (
  # Get the API and secret keys: https://support.upguard.com/upguard/using-the-api.html#authorization-header
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [Parameter(Mandatory=$true)][string]$SecretKey,
  [Parameter(Mandatory=$true)][string]$Url,
  # Get Environment ID from URL when navigating to desired environment in UpGuard UI
  [int]$EnvironmentID,
  # Date format YYYY-mm-dd
  [Parameter(Mandatory=$true)][string]$StartDate = '2019-01-01',
  [Parameter(Mandatory=$true)][string]$EndDate = '2019-01-02'
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
        Write-Verbose "Retrieving $($Endpoint) page $($Body.page)..."
        $new = Invoke-WebRequest -Method $Method -Uri $Endpoint -Headers $headers -Body $Body -ContentType "application/json"
        if ($new.StatusCode > 400){throw [System.Exception] "$($new.StatusCode.ToString()) $($new.StatusDescription)"}
        $new = ConvertFrom-Json $new.Content
        Write-Verbose "$($new)"

        if ($CombineAttribute -ne "") { $new = $new | Select -ExpandProperty $CombineAttribute }
        $result += $new
        Write-Verbose "After retrieving page $($Body.page), result now has $($result.Count) items"
        if ([int]$new.Count -lt [int]$Body.per_page) { return $result }
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

function Get-CI-Type
{
  param
  (
    [string]$Path
  )
  $Path = $Path.Replace('{', '').Replace('|', '').Replace('}', '').Replace('"', '').Split(',')
  return $Path -Join " -> "
}

function Get-CI-Path
{
  param
  (
    [string]$Path,
    [string]$Name
  )
  $Path = $Path.Replace('{', '').Replace('|', '').Replace('}', '').Replace('"', '').Split(',')
  $Path = "$($Path)$($Name)"
  return $Path -Join " -> "
}

function Get-Diff-Type
{
  param
  (
    [string]$Old,
    [string]$New
  )
  If ($Old -ne $Null) { return "Added" }
  If ($New -ne $Null) { return "Removed" }
  return "Updated"
}

function Aggregate-Per-Difference-Set
{
  param
  (
    [Object[]]$Diffs
  )

  If ($Diffs.Count -Eq 0) { return @{} }

  $AggregatedDiffs = @{}
  $NodeIDs = @()
  $NewScanIDs = @()

  # Initialize hashing algorithm
  $MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
  $UTF8 = New-Object -TypeName System.Text.UTF8Encoding

  $ScanDiffs = @{}
  Foreach ($Diff in $Diffs)
  {
    # For stats
    $NodeIDs += $Diff.node_id
    $NewScanIDs += $Diff.new_scan_id

    $Key = $Diff.new_scan_id
    $CIPath = Get-CI-Path -Path $Diff.path
    $DiffType = Get-Diff-Type -Old $Diff.old_attrs -New $Diff.new_attrs

    If ($ScanDiffs.Keys -NotContains $Key) { $ScanDiffs[$Key] = @{} }
    $ScanDiffs[$Key].node_id = $Diff.node_id
    $ScanDiffs[$Key].node_name = $Diff.node_name
    $ScanDiffs[$Key].created_at = $Diff.created_at
    If ($ScanDiffs[$Key].Keys -NotContains "stats") { $ScanDiffs[$Key].stats = @{} }
    If ($ScanDiffs[$Key].stats.Keys -NotContains $CIPath) { $ScanDiffs[$Key].stats[$CIPath] = @{} }

    # Increment a counter for the diff type
    If ($ScanDiffs[$Key].stats[$CIPath] -NotContains $DiffType) { $ScanDiffs[$Key].stats[$CIPath][$DiffType] = 0 }
    $ScanDiffs[$Key].stats[$CIPath][$DiffType] += 1

    # Now store a checksum of the diff in an array
    If ($ScanDiffs[$Key].Keys -NotContains "diff_checksums") { $ScanDiffs[$Key].diff_checksums = @() }
    $ScanDiffs[$Key].diff_checksums += [System.BitConverter]::ToString($MD5.ComputeHash($UTF8.GetBytes("$($Diff['old_attrs'])$($Diff['new_attrs'])")))
    $ScanDiffs[$Key].diff_checksums = Sort-Object -InputObject $ScanDiffs[$Key].diff_checksums
  }

  # Now we can loop through and aggregate like difference sets
  Foreach ($ScanID in $ScanDiffs.Keys)
  {
    $DiffData = $ScanDiffs[$ScanID]

    # Create a single checksum for the entire diff set
    $DiffsetChecksum = [System.BitConverter]::ToString($MD5.ComputeHash($UTF8.GetBytes($DiffData.diff_checksums -Join "")))

    # Check if we've seen this change elsewhere
    If ($AggregatedDiffs.Keys -NotContains $DiffsetChecksum)
    {
      # Didn't find it, so create a new entry
      $AggregatedDiffs[$DiffsetChecksum] = @{}
      $AggregatedDiffs[$DiffsetChecksum].stats = $DiffData.stats
      $AggregatedDiffs[$DiffsetChecksum].nodes = @()
    }

    # Add this node into the array
    $Node = @{
      node_id = $DiffData.node_id
      node_name = $DiffData.node_name
      scan_id = $ScanID
      timestamp = $DiffData.created_at
      # url =
      # "url": get_node_url(url, diff_data.node_id, scan_id, True)})
    }
    $AggregatedDiffs[$DiffsetChecksum].nodes += $Node
  }

  Write-Host "Diffs found   : $($Diffs.Count)"
  Write-Host "Unique Sets   : $($AggregatedDiffs.Count)"
  Write-Host "Nodes Affected: $($NodeIDs.Count)"
  Write-Host "Scans Affected: $($NewScanIDs.Count)"
  Write-Host "-------------------"

  return $AggregatedDiffs
}

$Environments = @()
If ($EnvironmentID) { $Environments += $EnvironmentID }
else
{
  $Envs = UpGuard-WebRequest -Endpoint "$($Url)/api/v2/environments.json" -ApiKey $ApiKey -SecretKey $SecretKey
  Foreach ($Env in $Envs)
  {
    $Environments += $Env.id
  }
}

Foreach ($Environment in $Environments)
{
  $Body = @{
    environment_id = $Environment
    date_from = $StartDate
    date_to = $EndDate
  }
  $Diffs = UpGuard-WebRequest -Endpoint "$($Url)/api/v2/diffs.json" -ApiKey $ApiKey -SecretKey $SecretKey -Paginate -CombineAttribute "diff_items"

  $AggregatedDiffs = Aggregate-Per-Difference-Set -Diffs $Diffs
  Foreach ($Diff in $AggregatedDiffs.Values)
  {
    $Summary = "Differences detected in configuration item '$($Diff.stats.Keys -Join ', ')'"
    $Description = ""
    Foreach ($Node in $Diff.nodes)
    {
      Write-Host "Diff found for node $($Node.node_name):"
      Foreach ($CIPath in $Diff.stats.Keys)
      {
        $DiffType = $Diff.stats[$CIPath]
        Write-Host "  CI Path: $($CIPath)"
        Write-Host "  Change : $($DiffType.Keys -Join ', ')"

        # TODO: Handle each change for each node in diff set
        # Variables:
        # * $Node     : Node detail hash, usable variables are: node_name, node_id
        # * $CIPath   : Path to the UpGuard CI (ex. 'services -> windows')
        # * $DiffType : The type of change: Added, Modified, Removed (This variable is a hash)
        # * $Timestamp: Time when the diff was detected
      }
    }
  }
}
