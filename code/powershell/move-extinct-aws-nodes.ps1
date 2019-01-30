# For all AWS EC2 nodes in UpGuard, if we can't seem to find that node's
# existence in AWS, move the node to a holding node group for final
# review before deletion.

# Will need to install the AWSPowerShell tools first:
# > Install-Module -Name AWSPowerShell
# And set your AWS credentials:
# > Set-AWSCredential -AccessKey <AWS access key> -SecretKey <AWS secret key>
# Usage:
#     powershell .\move-extinct-aws-nodes.ps1 -ApiKey "UpGuard API key" -SecretKey "UpGuard secret key" -Url "https://you.upguard.com" -DestNodeGroupID "123"
# Params:
#     -ApiKey               : your UpGuard API Key
#     -SecretKey            : your UpGuard API Secret Key
#     -Url                  : the full URL of your UpGuard instance, for example 'https://you.upguard.com'
#     -DestNoGroupID        : the ID of the node group you want to move extinct nodes to for final review and possible delete
#     -IngoreNodeNamePrefix : if specified, nodes with names matching this prefix will be ignored and not moved to the dest node group
#     -Insecure             : if you are using a self signed or not-prefect SSL cert, this prevents SSL cert checks connecting to your appliance
#     -DryRun               : if specified, the script prints out what it would like to do rather than actually moving any nodes

param (
      [string]$ApiKey = '',
      [string]$SecretKey = '',
      [string]$Url = 'https://',
      [string]$DestNodeGroupID = '',
      [string]$IgnoreNodeNamePrefix = '',
      [switch]$Insecure,
      [switch]$DryRun
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

$headers = @{'Authorization' = "Token token=""$($ApiKey)$($SecretKey)""";
                 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

Write-Host "about to ask for a list of all nodes"
$nodes = Invoke-WebRequest -Uri "$($Url)/api/v2/nodes.json?page=1&per_page=50000" -Headers $headers -Method "GET"

if ($nodes.StatusCode > 400)
{
  throw [System.Exception] "$($nodes.StatusCode.ToString()) $($nodes.StatusDescription)"
}
else
{
  $nodes = ConvertFrom-Json -InputObject $nodes

  ForEach ($node in $nodes) {
    Write-Host "about to get more information on node $($node.name)"
    # Need to lookup more information about this particular node first
    $node_details = Invoke-WebRequest -Uri "$($Url)/api/v2/nodes/$($node.id).json" -Headers $headers -Method "GET"
    $node_details = ConvertFrom-Json -InputObject $node_details

    # if we specified an ignore prefix, if the node matches the prefix, then skip
    if ("$($IgnoreNodeNamePrefix)" -ne "") {
      if ($node_details.name.StartsWith($IgnoreNodeNamePrefix)) {
        Write-Host "skipping $($node_details.name) because it matches the IgnoreNodeNamePrefix prefix"
        continue
      }
    }

    # only do the check for EC2 nodes at the moment
    if ("$($node_details.operating_system_id)" -eq "2801") {
      # internally, we store the AWS EC2 instance external ID in the `url` field (for technical reasons)
      $instance_id = $node_details.url
      $region = $node_details.hostname

      # check if this instance still exists in AWS
      Write-Host "about to check with AWS if an instance with ID $($instance_id) exists"
      $instance_exists = $true
      Try {
        $response = Get-EC2Instance -InstanceId $instance_id -Region $region
        Write-Host "=== I think the instance exists"
      } Catch {
        $instance_exists = $false
        Write-Host "=== I don't think the instance exists"
      }

      if ($instance_exists -eq $false) {
	  # replace this ID with the ID of the node group you want to add nodes to if they dont exist
          $holding_node_group_id = $DestNodeGroupID

	  if ($DryRun -eq $false) {
	      Write-Host "Adding node to the holding node group"

	      $response = Invoke-WebRequest -Uri "$($Url)/api/v2/nodes/$($node.id)/add_to_node_group.json?node_group_id=$($holding_node_group_id)" -Headers $headers -Method "POST"

	      if ($response.StatusCode > 400) {
	      	 throw [System.Exception] "$($response.StatusCode.ToString()) $($response.StatusDescription)"
	      }		
	  } else {
	      Write-Host "Would have tried to add node $($node.name) to the node group with ID=$($holding_node_group_id)"
	  }
      }

    } else {
      Write-Host "not an AWS EC2 instance node type - ignoring"
    }
  }
}
