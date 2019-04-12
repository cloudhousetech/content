# For SSH nodes in a particular node group, update their username/password.
# Use -dry_run to see what would be changed

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
$node_group_id = "<< node_group_id >>"
$new_username = "<< new_username >>"
$new_password = "<< new_password >>"
$dry_run = $true

$headers = @{'Authorization' = 'Token token="' + $api_key + $secret_key + '"';
                 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

$nodes = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/node_groups/$node_group_id/nodes.json?page=1&per_page=500") -Headers $headers -Method "GET"

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

        # Only update username/password for SSH nodes.
        if ($node_details.medium_type -ne 3) { continue }

        "Updating node {0} username/password" -f $node.name
        $body = @{"node" = @{"medium_username" = $new_username; "medium_password" = $new_password}}
        $body = ConvertTo-Json -InputObject $body
        
        if ($dry_run -eq $false)
        {
            $response = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes/ " + $node.id + ".json") -Body $body -Headers $headers -Method "PUT"
            if ($response.StatusCode > 400)
            {
                throw [System.Exception] $response.StatusCode.ToString() + " " + $response.StatusDescription
            }
        }
    }
}
