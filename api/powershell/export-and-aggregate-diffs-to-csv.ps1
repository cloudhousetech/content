param (
    [string]$ApiKey = '',
    [string]$SecretKey = '',
    [string]$Url = '',
    [int]$PerPage = 500,
    [int]$EnvironmentId,
    [int]$NodeGroupId,
    [int]$NodeId,
    [string]$DateFrom = '',
    [string]$DateTo = '',
    [bool]$IncludeIgnored = $false,
    [switch]$Insecure,
    [string]$OutputFilePath = 'C:\tmp\diffs.csv',
    [switch]$AggregateByNodeScan = $true
)

# Ignore SSL certificate if `-insecure` is used
if ($Insecure)
{
  add-type @"
  using System.Net;
  using System.Security.Cryptography.X509Certificates;
  public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
      ServicePoint srvPoint, X509Certificate certificate,
      WebRequest request, int certificateProblem) {
      return true;
    }
  }
"@
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::SSL3 -bor [System.Net.SecurityProtocolType]::TLS;

$headers    = @{'Authorization' = "Token token=""$($ApiKey)$($SecretKey)""";'Accept' = 'application/json'; 'Content-Type' = 'application/json'}
$diffs      = $null
$allDiffs   = @()
$allIgnores = @()
$page       = 1

while ($diffs -eq $null -or ($diffs.Count + $ignored_items.Count) -eq $PerPage)
{
    $qs        = "page=$($page)&per_page=$($PerPage)&include_ignored=$($IncludeIgnored.ToString().ToLower())"
    $qs       += If ($EnvironmentId -ne 0)  { "&environment_id=$($EnvironmentId)" } Else { "" } 
    $qs       += If ($NodeGroupId   -ne 0)  { "&node_group_id=$($NodeGroupId)" }    Else { "" } 
    $qs       += If ($NodeId        -ne 0)  { "&node_id=$($NodeId)" }               Else { "" } 
    $qs       += If ($DateFrom      -ne "") { "&date_from=$($DateFrom)" }           Else { "" } 
    $qs       += If ($DateTo        -ne "") { "&date_to=$($DateTo)" }               Else { "" } 

    $full_url  = "$($Url)/api/v2/diffs.json?$($qs)"

    Write-Output "Making GET call to $($full_url)"

    try
    {
        $response = Invoke-WebRequest -Uri $full_url -Headers $headers -Method "GET"
    } 
    catch {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Output $responseBody
        break
    }

    # Check response size
    # You can update the page size (in parameter > make smaller), or the MaxJsonLength (below > make bigger)
    #   if you get Json parse errors due to response size 
    # Write-Output "  Response size: $($response.RawContentLength)"

    # Parse response
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
    $jsonserial      = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
    $jsonserial.MaxJsonLength = 15000000    # Increase max length allowed by JSON parser
    $parsed_response = $jsonserial.DeserializeObject($response)
    $diffs           = $parsed_response.diff_items
    $ignored_items   = $parsed_response.ignored_items

    Write-Output "  Got $($diffs.Count) diff records and $($ignored_items.Count) ignored items" 

    $allDiffs       += $diffs
    $allIgnores     += $ignored_items

    $page += 1
}

# Print totals
Write-Output "Total diffs found:   $($allDiffs.Count)"
if ($IncludeIgnored) { Write-Output "Total ignores found: $($allIgnores.Count)" }

# Check to see if we're dumping all diffs, or aggregating
if ($AggregateByNodeScan) {
    # Write header to file
    "Node,Diff URL" > $OutputFilePath
    $node_details = @{}

    foreach ($diff in $allDiffs) {
        # Check for this scan id in the hash already, otherwise skip
        if ($node_details.($diff.new_scan_id) -eq $null) {
            $node_details.Add($diff.new_scan_id, @{ 'node' = $diff.node_name; 'diff_url' = "$($Url)/node_groups#/nodes/$($diff.node_id)?state=show&scan_id=$($diff.new_scan_id)&compare_to_previous" })
        }
    }

    Write-Output "Individual node scans with diffs found: $($node_details.Keys.Count)"

    # Now build the CSV
    foreach ($item in $node_details.GetEnumerator()) {
       "`"$($item.Value.node)`", $($item.Value.diff_url)" >> $OutputFilePath
    }   
}
else {
    # Write data to file
    # Header first
    "Node,Environment Id,CI Name,Path,Old Value,Old Scan Id,New Value,New Scan Id" > $OutputFilePath

    foreach ($diff in $allDiffs) {
        $old_attrs = if ($diff.old_attrs -ne $null) { $diff.old_attrs.ToString().Replace("{", "").Replace("}", "").Replace("`"", "").Replace(",", ", ") } Else { "" }
        $new_attrs = if ($diff.new_attrs -ne $null) { $diff.new_attrs.ToString().Replace("{", "").Replace("}", "").Replace("`"", "").Replace(",", ", ") } Else { "" }

        "`"$($diff.node_name)`",`"$($diff.environment_id)`",`"$($diff.name)`",`"$($diff.path)`",`"$($old_attrs)`",`"$($diff.old_scan_id)`",`"$($new_attrs)`",`"$($diff.new_scan_id)`"" >> $OutputFilePath
    }
}
