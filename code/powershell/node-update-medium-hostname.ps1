# For WinRM nodes, update their medium_hostname if it's equal to a given connection manager medium_hostname.
# This script can be used in the situation where nodes have been added with a medium_hostname
# equal to that of the connection manager medium_hostname that should be scanning them.
# Use $dry_run = $true to see what would be changed.

# Ignore SSL certificate errors. Comment out if not needed.
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


$target_url = "<< upguard_appliance_hostname >>" # Without scheme
$api_key = "<< api_key >>"
$secret_key = "<< secret_key >>"
$connection_manager_hostname = "<< connection_manager_hostname >>"
$dry_run = $true

$headers = @{'Authorization' = 'Token token="' + $api_key + $secret_key + '"';
                 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

$nodes = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes?page=1&per_page=50000") -Headers $headers -Method "GET"

if ($nodes.StatusCode > 400)
{
  throw [System.Exception] $nodes.StatusCode.ToString() +
    " " + $nodes.StatusDescription
}
else
{
    $nodes = ConvertFrom-Json -InputObject $nodes

    ForEach ($node in $nodes)
    {
        # Need to perform an additional lookup to get detailed node information.
        $node_details = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes/" + $node.id) -Headers $headers -Method "GET"
        $node_details = ConvertFrom-Json -InputObject $node_details

        # Only update hostname for WinRM nodes.
        if ($node_details.medium_type -ne 7) { continue }
        # If the medium_hostname isn't set to the connection_manager_hostname, then there's nothing to repair here, continue on.
        if ($node_details.medium_hostname -ne $connection_manager_hostname) { continue }
        # Ignore connection managers added as nodes
        if ($node_details.name -eq $connection_manager_hostname ) { continue }

        if ($dry_run -eq $false)
        {
            "Updating node " + $node_details.name + " medium_hostname from " + $node_details.medium_hostname + " to " + $node_details.name
            $body = @{"node" = @{"medium_hostname" = $node_details.name}}
            $body = ConvertTo-Json -InputObject $body
            $response = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes/ " + $node.id + ".json") -Body $body -Headers $headers -Method "PUT"
            if ($response.StatusCode > 400)
            {
                throw [System.Exception] $response.StatusCode.ToString() + " " + $response.StatusDescription
            }
        } else {
            "Would update node " + $node_details.name + " medium_hostname from " + $node_details.medium_hostname + " to " + $node_details.name
        }
    }
}
