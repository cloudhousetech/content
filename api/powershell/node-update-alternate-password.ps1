# Update the alternate_password for a particular SSH node. 
# Can be used to set empty ("") passwords.

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

$target_url = "<< target_url >>" # Without scheme
$api_key = "<< api_key >>"
$secret_key = "<< secret_key >>"
$node_id = << node_id >>
$new_password = "" # Blank

$headers = @{'Authorization' = 'Token token="' + $api_key + $secret_key + '"';
                 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

# Need to perform an additional lookup to get detailed node information.
$node_details = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes/" + $node_id) -Headers $headers -Method "GET"
$node_details = ConvertFrom-Json -InputObject $node_details

# Only update password for SSH nodes.
if ($node_details.medium_type -ne 7) 
{ 
    "Node is not an SSH node, quitting."
    continue 
}

"Updating node id {0} alternate_password..." -f $node_id

$body = @{"node" = @{"alternate_password" = $new_password}}
$body = ConvertTo-Json -InputObject $body
        
$response = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes/ " + $node_id + ".json") -Body $body -Headers $headers -Method "PUT"
if ($response.StatusCode > 400)
{
    throw [System.Exception] $response.StatusCode.ToString() + " " + $response.StatusDescription
} else {
    $response
}
