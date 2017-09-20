Param(    
    [switch]$disableSSLCert,
    [switch]$disableDebugOutput,
    [string]$status,
    [string]$lastScanStatus,
    [string]$encryptionProtocol,
    [string]$outputFormat
)

$scheme = 'https' #scheme can be https or http
$secret_key = '' #secret key shown when API enabled in Manage Accounts | Account | enable api access
$api_key = '' #service Api key under Manage Accounts | Account 
$url = '' #Example: 123.0.0.1

Add-Type -AssemblyName System.Web.Extensions
$json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = 104857600 #100mb as bytes, default is 2mb


<#
This script lists the nodes stored in UpGuard databases.
The resulting API response is stored in the $nodeArr variable which is an array of hashmaps, each holding a single node's information.

UpGuard Support Site Documentation: https://support.upguard.com/upguard/nodes-api-v2.html#index

Usage Instructions:
  - Machine must be running Powershell 3 and up
  - Please provide the secret_key, api_key, url, and appropriate scheme of your UpGuard Appliance
    in the fields above in order to run this script.
    
Optional API Query Input Flags: 
  - status: Filters node list by active, deleted, or detected status.
    Inputs: active, deleted, detected
  - lastScanStatus: Filters node list by result of the last scan of that node.
    Inputs: success, failure, offline, timeout, error, exception, all_failures

Optional Script Flags:
  - outputFormat: Determinds the output format of nodes. Outputs to console by default
    Inputs: json
  - disableSSLCert: Disables SSL Certificate check for the API call.
  - disableDebugOutput: Disables debugging output.
  - encryptionProtocol: Updates the encryption protocol to use. Uses TLS 1.2 by default.
    Inputs: TLS1.1, TLS1.0, SSL3

Example Usage:
  - List all nodes without requiring an SSLCertificate check:
    ./path_to_script/list_nodes.ps1 -disableSSLCert
  - List all nodes that are active and have had a succesful last scan:
    ./path_to_script/list_nodes.ps1 -status active -lastScanStatus success all_failures

Example Script Output:
  Name:              First Node
  Node Id:           1
  Environment Id:    2
  Node Type:         SV
  Mac Address:       02:c3:89:c0:82:19
  IP Address:        0.0.0.0
  Short Description: The first node added
  OS Family Id:      2
  OS ID:             2
  External Id:       i-ac49774
  Online:            True
  Url:               http://192.168.88.1:3000/api/v2/nodes/1
#>

function Write-OptionalDebug {
    param([string]$output)
    if (-Not $disableDebugOutput) {
        Write-Host $output
    }
}

function Set-SslCertificateValidation
{
  <#
    .SYNOPSIS
    This function enables or disables SSL Cert validation in your PowerShell session.  Calling this affects SSL validation for ALL function calls in the session!
    
    .PARAMETER Disable
    If specified, validation is disabled.  If not specified (the default) validation is re-enabled.
    
    .EXAMPLE
    Set-SslCertificateValidation -Disable
    #  Disables SSL Cert validation

    .EXAMPLE
    Set-SslCertificateValidation
    #  Re-enables SSL Cert validation again
  #>
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
        [string]$Url = $url,
        [string]$SecretKey = $secret_key,
        [string]$ApiKey = $api_key,
        [string]$RequestPath = $null,
        [string]$FullPath = $null,
        [string]$Scheme = $scheme,
        [string]$Method = "GET"
    )

    if ($RequestPath -eq $null -and $FullPath -eq $null) {
        throw [System.Exception] "Must provide one of -RequestPath or -FullPath"
    }

    $headers = @{'Authorization' = 'Token token="' + $ApiKey + $SecretKey + '"'} #; 'Accept' = 'application/json'}
    Write-OptionalDebug "Request path: $RequestPath`nFull path: $FullPath"
   
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

    Write-OptionalDebug "Got status code $($req.StatusCode)`n"

    $content = $req.Content
    $nodes = $json.Deserialize($content, [System.Object])
    $nodes
}




function Start-Main {
    #SSL Certificate Check
    if($disableSSLCert) {
        Set-SslCertificateValidation -Disable
        Write-OptionalDebug "SSL Certificate checking is disabled"
    } else {
        Write-OptionalDebug "SSL Certificate checking is enabled"
    }

    #Encryption Protocol Setting
    if($encryptionProtocol -eq "") {
        Write-OptionalDebug "Enforcing TLS 1.2"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } else {
        switch ($encryptionProtocol) {
            "TLS1.1"{
                Write-OptionalDebug "Enforcing TLS 1.1"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11}
            "TLS1.0"{
                Write-OptionalDebug "Enforcing TLS 1.0"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls}
            "SSL3"{
                Write-OptionalDebug "Enforcing SSL 3"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3}
            default{
                throw [System.Exception] "Permitted values for encryptionProtocol are: TLS1.1, TSL1.0, and SSL3"}
        }
    }
    
    $page = 1
    $perPage = 500
    $nodeCount = $perPage
    $nodeArr = @() #Nodes are stored in an array for reuse

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
            "id" = $node."id";
            "environment_id" = $node."environment_id";
            "node_type" = $node."node_type";
            "mac_address" = $node."mac_address";
            "ip_address" = $node."ip_address";
            "short_description" = $node."short_description";
            "operating_system_family_id" = $node."operating_system_family_id";
            "operating_system_id" = $node."operating_system_id";
            "external_id" = $node."external_id";
            "online" = $node."online"
            "url" = $node."url"}
        }
        $page++
    }

    if($outputFormat -eq "json") {
        $json.Serialize($nodeArr)
    } else {
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
