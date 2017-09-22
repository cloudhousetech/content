Param(    
    [switch]$disableSSL,
    [switch]$disableDebugOutput,
    [switch]$printJSON
)

# Authorization
$url =        '' # Example: https://123.0.0.1 or http://<my-server>.com
$api_key =    '' # Service API key under Manage Accounts | Account
$secret_key = '' # Secret key shown when API enabled in Manage Accounts | Account | enable API access

# Added serializer for parsing large JSON responses
Add-Type -AssemblyName System.Web.Extensions
$json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = 104857600 #100mb as bytes, default is 2mb

# Usage Instructions:
#   - To use, please input the Authorization parameters above for URL, api_key, and secret_key
#   - Minimum Requirements: Powershell 3 and up
#
# Optional Script Flags:
#   - printJSON: Returns results in JSON format
#   - disableSSL: Disables SSL Certificate check for the API call.
#   - disableDebugOutput: Disables debugging output.
#
# Example Usage:
#   - List all node groups and disable SSLCertificate check:
#     ./<path_to_script>/list_node_groups.ps1 -disableSSLCert

function Write-OptionalDebug {
    param([string]$output)
    if (-Not $disableDebugOutput) {
        Write-Host $output
    }
}

function Set-SslCertificateValidation
{
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
        [string]$Method      = "GET"
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
        $uri = "$($Scheme)://$Url/$RequestPath"
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

    
    $page           = 1
    $perPage        = 500
    $nodeGroupCount = $perPage
    $nodeGroupArr   = @() #Nodes are stored in an array for reuse
    
    while($nodeGroupCount -eq $perPage) {
        $nodeGroups = Invoke-UpGuardApi -RequestPath "api/v2/node_groups.json?page=$($page)&per_page=$($perPage)"
        $nodeGroupCount = $nodeGroups.Length
        ForEach($nodeGroup in $nodeGroups) {
            $nodeGroupArr += @{
            "name"        = $nodeGroup."name";
            "id"          = $nodeGroup."id";
            "description" = $nodeGroup."description";
            "node_rules"  = $nodeGroup."node_rules";
            "url"         = $nodeGroup."url";
            }
        }
        $page++
    }

    if($printJSON -eq "json") {
        $json.Serialize($nodeGroupArr)
    } else {
        Write-OptionalDebug "Retrieved $($nodeGroupArr.count) nodes`n"
        ForEach($nodeGroup in $nodeGroupArr) {        
            Write-Host "Name:          $($nodeGroup["name"])"
            Write-Host "Node Group Id: $($nodeGroup["id"])"
            Write-Host "Description:   $($nodeGroup["description"])"
            Write-Host "Node Rules:    $($nodeGroup["node_rules"])"
            Write-Host "Url:           $($nodeGroup["url"])`n"
        }
    }
}

Start-Main
