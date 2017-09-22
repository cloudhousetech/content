Param(    
    [switch]$disableSSL,
    [switch]$disableDebugOutput,
    [switch]$printJSON,
    [string]$status,
    [string]$lastScanStatus
)

# Authorization
$url =        '' # Example: https://123.0.0.1 or http://<my-server>.com
$api_key =    '' # Service Api key under Manage Accounts | Account
$secret_key = '' # Secret key shown when API enabled in Manage Accounts | Account | enable API access

# Added serializer for parsing large JSON responses
Add-Type -AssemblyName System.Web.Extensions
$json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = 104857600 #100mb as bytes, default is 2mb

# Usage Instructions:
#   - To use, please input the Authorization parameters above for URL, api_key, and secret_key
#   - Minimum Requirements: Powershell 3 and up
#    
# Optional API Query Input Flags: 
#   - status: Filters node list by active, deleted, or detected status.
#     Inputs: active, deleted, detected
#   - lastScanStatus: Filters node list by result of the last scan of that node.
#     Inputs: success, failure, offline, timeout, error, exception, all_failures
#
# Optional Script Flags:
#   - returnJSON: Returns results in JSON format
#   - disableSSLCert: Disables SSL Certificate check for the API call.
#   - disableDebugOutput: Disables debugging output.
#
# Example Usage:
#   - List all nodes without requiring an SSLCertificate check:
#     ./path_to_script/list_nodes.ps1 -disableSSLCert
#   - List all nodes that are active and have had a succesful last scan:
#     ./path_to_script/list_nodes.ps1 -status active -lastScanStatus success

function Write-OptionalDebug {
    param([string]$output)
    if (-Not $disableDebugOutput) {
        Write-Host $output
    }
}

function Set-SslCertificateValidation {
# This function enables or disables SSL Cert validation in your PowerShell session.  Calling this affects SSL validation for ALL function calls in the session!
#    
# Optional Flag
#   - Disable: If specified, validation is disabled.  If not specified (the default) validation is re-enabled.
#    
# Examples
#   - Disable SSL Cert validation
#     Set-SslCertificateValidation -Disable
#
#   - Re-enable SSL Cert validation
#     Set-SslCertificateValidation
    param
    ([switch] $Disable)
    $type = [AppDomain]::CurrentDomain.GetAssemblies().ExportedTypes | Where-Object { $_.Name -ieq "TrustAllCertsPolicy" }
  
    if ( !$type ) {
    #  Disable SSL Certificate validation:
    Add-Type -TypeDefinition @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy 
        {
            public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,WebRequest request, int certificateProblem) 
            {
                return true;
            }
        }
"@
    }

  if ( $Disable ) {
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
  } else {
    [System.Net.ServicePointManager]::CertificatePolicy = $null
  }
}

function Invoke-UpGuardApi {
    param(
        [string]$Url         = $url,
        [string]$SecretKey   = $secret_key,
        [string]$ApiKey      = $api_key,
        [string]$RequestPath = $null,
        [string]$FullPath    = $null,
        [string]$Scheme      = $scheme,
        [string]$Method       = "GET"
    )

    if ($RequestPath -eq $null -and $FullPath -eq $null) {
        throw [System.Exception] "Must provide one of -RequestPath or -FullPath"
    }

    $headers = @{'Authorization' = 'Token token="' + $ApiKey + $SecretKey + '"'} #; 'Accept' = 'application/json'}
   
    $uri = ''

    if ($FullPath -ne $null -and $FullPath -ne '') {
        if (-not ($FullPath -match ".*\.json.*")) {
            $components = $FullPath.Split("?")
            $FullPath = "$($components[0]).json?$($components[1])"
        }
        $uri = $FullPath
    } else {
        $uri = "$Url/$RequestPath"
    }
    
    Write-OptionalDebug "Attempting to invoke $uri with $Method"

    try {
        $req = Invoke-WebRequest -Uri $uri -Method $Method -Headers $headers -UseBasicParsing
    } catch {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        $respJson = ConvertFrom-Json $responseBody
        Write-Output "Got Status Code $($_.Exception.Response.StatusCode): $($respJson."error")"
        break
    }
    $content = $req.Content
    $nodes   = $json.Deserialize($content, [System.Object])
    $nodes
}

function Start-Main {
    # SSL Certificate Check
    if($disableSSL) {
        Set-SslCertificateValidation -Disable
        Write-OptionalDebug "SSL Certificate checking is disabled"
    } else {
        Write-OptionalDebug "SSL Certificate checking is enabled"
    }

    # Encryption Protocol Setting
    Write-OptionalDebug "Enforcing TLS 1.2"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $page      = 1
    $perPage   = 500
    $nodeCount = $perPage
    $nodeArr   = @() # Nodes are stored in an array for reuse

    $statusString = ""
    if($status -ne "") {
        $statusString = "&status=$($status)"
    }

    $lastScanString = ""
    if($lastScanStatus -ne  "") {
       $lastScanString = "&lastScanStatus=$($lastScanStatus)"
    }
    
    while($nodeCount -eq $perPage) {
        $nodes = Invoke-UpGuardApi -RequestPath "api/v2/nodes.json?page=$($page)&per_page=$($perPage)$($statusString)$($lastScanString)"
        $nodeCount = $nodes.Length
        ForEach($node in $nodes) {
            $nodeArr += @{"name" = $node."name";
            "id"                         = $node."id";
            "environment_id"             = $node."environment_id";
            "node_type"                  = $node."node_type";
            "mac_address"                = $node."mac_address";
            "ip_address"                 = $node."ip_address";
            "short_description"          = $node."short_description";
            "operating_system_family_id" = $node."operating_system_family_id";
            "operating_system_id"        = $node."operating_system_id";
            "external_id"                = $node."external_id";
            "online"                     = $node."online"
            "url"                        = $node."url"}
        }
        $page++
    }

    if($printJSON) {
        $json.Serialize($nodeArr)
    } else {
        Write-OptionalDebug "Retrieved $($nodeArr.count) nodes`n"
        ForEach($node in $nodeArr) {        
            Write-Host "Name:              $($node["name"])"
            Write-Host "Node Id:           $($node["id"])"
            Write-Host "Environment Id:    $($node["environment_id"])"
            Write-Host "Node Type:         $($node["node_type"])"
            Write-Host "Mac Address:       $($node["mac_address"])"
            Write-Host "IP Address:        $($node["ip_address"])"
            Write-Host "Short Description: $($node["short_description"])"
            Write-Host "OS Family Id:      $($node["operating_system_family_id"])"
            Write-Host "OS ID:             $($node["operating_system_id"])"
            Write-Host "External Id:       $($node["external_id"])"
            Write-Host "Online:            $($node["online"])"
            Write-Host "Url:               $($node["url"])`n"
        }
    }
}

Start-Main
