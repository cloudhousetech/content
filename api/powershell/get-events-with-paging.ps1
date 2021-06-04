 
param (
    [string]$SecretKey = '',
    [string]$ApiKey = '',
    [string]$Url = 'https://demo.upguard.com',
    [int]$PerPage = 500,
    [string]$ViewName = 'User Logins',
    [string]$DateFrom = '2020-01-01',
    [string]$DateTo = '2020-01-02',
    [bool]$IncludeIgnored = $false,
    [switch]$Insecure,
    [string]$OutputFilePath = 'C:\......',
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
$events     = $null
$allEvents  = @()
$page       = 1

while ($events -eq $null -or $events.Count -eq $PerPage)
{
    $qs        = "page=$($page)&per_page=$($PerPage)"
    $qs       += If ($ViewName -ne "") { "&view_name=$($ViewName)" } Else { "" } 
    $qs       += If ($DateFrom -ne "") { "&date_from=$($DateFrom)" } Else { "" } 
    $qs       += If ($DateTo   -ne "") { "&date_to=$($DateTo)" }     Else { "" } 
    
    $full_url  = "$($Url)/api/v2/events.json?$($qs)"

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
    $events          = $parsed_response
    
    Write-Output "  Got $($events.Count) events" 

    $allEvents      += $events
    
    $page += 1
}

# Print totals
Write-Output "Total events found:   $($allEvents.Count)"

# Check to see if we're dumping all diffs, or aggregating
# Write data to file
# Header first
"Event Date,Variables" > $OutputFilePath

foreach ($event in $allEvents) {
"$($event.created_at),`"$(($event.variables.getenumerator() | Sort-Object value -descending | Format-Table | Out-String).ToString().Trim())`"" >> $OutputFilePath
} 
