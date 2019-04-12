param (
    [string]$node,
    [string]$cm_group_name = 'Windows',
    [string]$api_key = '7c644624af06cdce1eb4a8288c9371160fc1477cfd1345b59732397c52734bf0', #'api-key-here',
    [string]$secret_key = 'a2bd1d6a3d5e208d59310f8eda3fcb542fdfaea085407265142e41a52e5360a7', #'secret-key-here',
    [string]$url = 'https://appliance.upguard.org', #'https://my.upguard.url',
    [switch]$insecure = $false
)

# Perform an API request and return the result as a Powershell object
function UpGuard-WebRequest
{
    param
    (
        [string]$method = 'Get',
        [string]$endpoint,
        [hashtable]$body = @{}
    )
    [System.Net.ServicePointManager]::CertificatePolicy
    # Handle very large JSON responses (such as scan data)
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    $jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    $jsonserial.MaxJsonLength  = 67108864

    $headers = @{'Authorization' = 'Token token="' + $($api_key) + $($secret_key) + '"'; 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}
    $req = $null
    Write-Output $endpoint
    if ($method -in "Get","Delete"){$req = Invoke-WebRequest -Method $method -Uri $endpoint -Headers $headers}
    else{$req = Invoke-WebRequest -Method $method -Uri $endpoint -Headers $headers -Body ($body | ConvertTo-Json)}
    if ($req)
    {
        if ($req.StatusCode > 400){throw [System.Exception] "$($req.StatusCode.ToString()) $($req.StatusDescription)"}
        else{return $jsonserial.DeserializeObject($req.Content)}
    }
}

Write-Output "Disabling UpGuard service on $($node)..."
Set-Service -Name 'upguardd' -StartupType Disabled -Status Stopped -PassThru -ComputerName "$($node)"
Write-Output "...Done"

# Ignore SSL certificate if `-ignore` is used
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

# Need to perform an additional lookup to get detailed node information.
$node_id = UpGuard-WebRequest -method "Get" -endpoint "$($url)/api/v2/nodes/lookup.json?name=$($node)"
$node_id = $node_id.node_id
$cm_groups = UpGuard-WebRequest -method "Get" -endpoint "$($url)/api/v2/connection_manager_groups.json"
$cm_group_id = 0
foreach	($cm in $cm_groups)
{
  if($cm.name -eq $cm_group_name)
  {
    $cm_group_id = $cm.id
  }
}
Write-Output "Getting details for $($node)..."
$details = UpGuard-WebRequest -method "Get" -endpoint "$($url)/api/v2/nodes/$($node_id).json"
Write-Output "...Done"
Write-Output "Setting $($node) to agentless..."
$body = @{"medium_hostname" = $details.name; "medium_type" = 7; "connection_manager_group_id" = $cm_group_id}
UpGuard-WebRequest -method "Put" -endpoint "$($url)/api/v2/nodes/$($node_id).json" -body $body
Write-Output "...Done"

UpGuard-WebRequest -method "Get" -endpoint "$($url)/api/v2/nodes/$($node_id).json"
