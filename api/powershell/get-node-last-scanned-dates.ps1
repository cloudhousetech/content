param (
    [string]$ApiKey = '<API_KEY>',
    [string]$SecretKey = '<SECRET_KEY>',
    [string]$Url = '<YOUR_SITE>.upguard.com',
    [string]$Scheme = 'https',
    [switch]$Insecure,
    [string]$OutputFilePath = 'nodes.csv',
    [switch]$DebugOutput = $true
)

function Write-OptionalDebug {
    param([string]$output)
    if ($DebugOutput) {
        Write-Host $output
    }
}

function Invoke-UpGuardApi {
    param(
        [string]$Url,
        [string]$SecretKey,
        [string]$ApiKey,
        [string]$RequestPath = $null,
        [string]$FullPath = $null,
        [string]$Scheme = 'https',
        [string]$Method = "GET",
        [bool]$Raw = $false,
        $Body = $null
    )

    if ($RequestPath -eq $null -and $FullPath -eq $null) {
        throw [System.Exception] "Must provide one of -RequestPath or -FullPath"
    }

    $headers = @{'Authorization' = 'Token token="' + $ApiKey + $SecretKey + '"'} #; 'Accept' = 'application/json'}
    Write-OptionalDebug "Req path: $RequestPath full path: $FullPath"
   
    $uri = ''

    if ($FullPath -ne $null -and $FullPath -ne '') {
        if (-not ($FullPath -match ".*\.json.*")) {
            $components = $FullPath.Split("?")
            $FullPath = "$($components[0]).json?$($components[1])"
        }
        $uri = $FullPath
    }
    else {
        $uri = "$($Scheme)://$Url/$RequestPath"
    }
    
    Write-OptionalDebug "Attempting to invoke $uri with $Method"

    if ($TestRun -ne $true) {
        if ($Body -ne $null) {
            $Body = ConvertTo-Json -InputObject $Body
            Write-Output $uri
            Write-Output $Method
            Write-Output $Body
            $response = Invoke-WebRequest -Uri $uri -Method $Method -Headers $headers -Body $Body 
        } else {
            $response = Invoke-WebRequest -Uri $uri -Method $Method -Headers $headers
        }

        Write-OptionalDebug "Got status code $($response.StatusCode)"

        if ($req.StatusCode -gt 400) {
            throw [System.Exception] "$($response.StatusCode) $($response.StatusDescription)"
        }

        if ($Raw) {
            $response.Content
        } else {
            $response.Content | ConvertFrom-Json
        }
    }
}

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
$nodes      = $null

# Create output file and add header
"Node,Last Scan Date,URL" > $OutputFilePath

$nodes = Invoke-UpGuardApi -Url $Url -Scheme $Scheme -ApiKey $ApiKey -SecretKey $SecretKey -RequestPath "api/v2/nodes.json"



foreach ($node in $nodes) {
    # Now get the node details
    $node_detail = Invoke-UpGuardApi -Url $Url -Scheme $Scheme -ApiKey $ApiKey -SecretKey $SecretKey -RequestPath "api/v2/nodes/$($node.id).json"
    $last_scan_date = "N/A"

    if ($node_detail.last_scan_id -ne $null -and $node_detail.last_scan_id -ne 0) {
        # Get the last scan details
        $response = Invoke-UpGuardApi -Url $Url -Scheme $Scheme -ApiKey $ApiKey -SecretKey $SecretKey -Raw $true -RequestPath "api/v2/node_scans/$($node_detail.last_scan_id).json" 
        
        # Parse response
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
        $jsonserial               = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
        $jsonserial.MaxJsonLength = 15000000    # Increase max length allowed by JSON parser
        $scan_detail              = $jsonserial.DeserializeObject($response)
        
        $last_scan_date = $scan_detail.created_at   
    }

    "`"$($node.name)`",`"$($last_scan_Date)`",`"$($Scheme)://$($Url)/node_groups#/nodes/$($node.id)`"" >> $OutputFilePath
}
