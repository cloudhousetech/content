############################################################################
# Author:      support@upguard.com                                         #
# Date:        June 2017                                                   #
# Description: Scripted configuration querying                             #
# Inputs:      Node group ID, CI name, CI value                            #
# Output:      Print (to standout) any nodes in the node group specified   #
#              that do not have the referenced CI value.                   #
############################################################################
 
param (
    [Parameter(Mandatory=$true)][string]$node_group_id, #TODO: Change this to accept node group name too.
    [string]$api_key = '<< api_key >>',
    [string]$secret_key = '<< secret_key >>',
    [string]$url = '<< https://your.appliance.url >>',
    [switch]$insecure = $false,
 
    [Parameter(ParameterSetName='Inventory', Mandatory=$true)][string]$inventory_ci,
    [Parameter(ParameterSetName='Inventory', Mandatory=$true)][string]$inventory_ci_value,
    [Parameter(ParameterSetName='Files', Mandatory=$true)][string]$file_name,
    [Parameter(ParameterSetName='Files', Mandatory=$true)][string]$file_line_expected
)

$VERSION = "v0.1"

# Perform an API request and return the result as a Powershell object
function UpGuard-WebRequest
{
    param
    (
        [string]$method = 'Get',
        [string]$endpoint,
        [hashtable]$body = @{}
    )
    $headers = @{'Authorization' = 'Token token="' + $($api_key) + $($secret_key) + '"'}
    # Write-Output "Method: $($method)"
    # Write-Output "Endpoint: $($endpoint)"
    # Write-Output "Body: $($body | ConvertTo-Json)"
    $req = $null
    if ($method -in "Get","Delete") {
        $req = Invoke-WebRequest -Method $method -Uri $endpoint -Headers $headers -ContentType "application/json"
    }
    else {
        $req = Invoke-WebRequest -Method $method -Uri $endpoint -Headers $headers -Body ($body | ConvertTo-Json) -ContentType "application/json"
    }
 
    if ($req) {
        if ($req.StatusCode > 400) {
            throw [System.Exception] "$($req.StatusCode.ToString()) $($req.StatusDescription)"
        }
        else {
            return $jsonserial.DeserializeObject($req.Content)
        }
    }
}
 
if ($insecure)
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
 
function CheckNodeFileContents($node) {
    Try
    {
        $node_conf = UpGuard-WebRequest -Method Get -endpoint "$($url)/api/v2/nodes/$($node.id)/ci_data.json?ci_type=files"
        if ($node_conf.linux.ContainsKey("$($file_name)")) {
            $file_ci = $node_conf.linux["$($file_name)"]
            if ($file_ci.ContainsKey("text_file_id")) {
                $text_file_id = $file_ci.text_file_id
                Try
                {
                    $text_file_detail = UpGuard-WebRequest -Method Get -endpoint "$($url)/api/v2/nodes/$($node.id)/raw_file.json?raw_file_id=$($text_file_id)"
                    if ($text_file_detail.ContainsKey("data")) {
                        $text_file_data = $text_file_detail.data
                        if ($text_file_data -match $file_line_expected) {
                            Write-Output "$($node.name), line found in file"
                        } else {
                            Write-Output "$($node.name), line not found in file"
                        }
                    } else {
                        Write-Output "$($node.name), text file id $text_file_id returned no 'data' key (contact support)"
                    }
                } Catch [Net.WebException] { Write-Output "...$($node.name), could not obtain text file details for text file id $($text_file_id)" }
            } else {
                Write-Output "$($node.name), file contents are not being scanned (review scan options)"
            }
        } else {
            Write-Output "$($node.name), file is not being scanned (check file name and node scan options)"
        }
    }
    Catch [Net.WebException] { Write-Output "error, could not retrieve files for node id $($node.id)" }
}
 
function CheckNodeInventory($node) {
    Try
    {
        $node_conf = UpGuard-WebRequest -Method Get -endpoint "$($url)/api/v2/nodes/$($node.id)/ci_data.json?ci_type=inventory"
        #Write-Output $node_conf 
        if ($node_conf.ContainsKey("facts")) {
            $node_facts = $node_conf.facts
           if ($node_facts.ContainsKey($inventory_ci)) {
                $node_facts_ci = $node_facts[$inventory_ci]
                if ($node_facts_ci.value -match $inventory_ci_value) {
                    Write-Output "$($node.name), value matches"
                } else {
                    Write-Output "$($node.name), value does not match (actual '$($node_facts_ci.value)')"
                }
            } else {
                Write-Output "$($node.name), '$($inventory_ci)' not present in inventory section"
            }
        } else {
            Write-Output "$($node.name), has no facts"
        }
    }
    Catch [Net.WebException] { Write-Output "error, could not retrieve files for node id $($node.id)" }
}
 
###########
# Prepare #
###########
 
# Handle very large JSON responses
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
$jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
$jsonserial.MaxJsonLength  = 67108864
 
Try
{
    $nodes = UpGuard-WebRequest -Method Get -endpoint "$($url)/api/v2/node_groups/$($node_group_id)/nodes.json"
    $param_set = $PSCmdlet.ParameterSetName
 
    if ($param_set -eq "Files") {
        Write-Output "==============================================================================================="
        Write-Output "Checking '$($file_name)' contains '$($file_line_expected)' accross $($nodes.length) nodes..."
        Write-Output "==============================================================================================="
        foreach ($node in $nodes) {
            CheckNodeFileContents($node)
        }
    } elseif ($param_set -eq "Inventory") {
        Write-Output "==============================================================================================="
        Write-Output "Checking '$($inventory_ci)' equals '$($inventory_ci_value)' accross $($nodes.length) nodes..."
        Write-Output "==============================================================================================="
        foreach ($node in $nodes) {
            CheckNodeInventory($node)
        }
    } else {
        Write-Output "Please specify a param set."
        Write-Output "==============================================================================================="
        Write-Output "Checking '$($inventory_ci)' equals '$($inventory_ci_value)' accross $($nodes.length) nodes..."
        Write-Output "==============================================================================================="
        foreach ($node in $nodes) {
            CheckNodeInventory($node)
        }
    }
}
Catch [Net.WebException] { Write-Output "fatal, exception finding nodes for node group id $($node_group_id) (check API credentials and node group id)"; Exit }