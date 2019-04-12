# For all nodes in a node group, update the password for each node

###############
# Configuration
###############

$target_url = "" # Hostname only, without scheme (leave off https)
$api_key = ""
$secret_key = ""
$from_node_group = 0
$password = ""
$dry_run = $true

###################
# End Configuration
###################

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
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::SSL3 -bor [System.Net.SecurityProtocolType]::TLS;

$headers = @{'Authorization' = "Token token=""$($api_key)$($secret_key)""";
                 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

$nodes = Invoke-WebRequest -Uri "https://$($target_url)/api/v2/node_groups/$($from_node_group)/nodes.json?page=1&per_page=50000" -Headers $headers -Method "GET"

if ($nodes.StatusCode > 400)
{
  throw [System.Exception] "$($nodes.StatusCode.ToString()) $($nodes.StatusDescription)"
}
else
{
    $nodes = ConvertFrom-Json -InputObject $nodes

    ForEach ($node in $nodes)
    {
        if ($dry_run -eq $false)
        {
            Write-Host -NoNewline "Updating password for node $($node.name)..."
            $body = @{"node" = @{"medium_password" = $password}}
            $body = ConvertTo-Json -InputObject $body
            $response = Invoke-WebRequest -Uri "https://$($target_url)/api/v2/nodes/$($node.id).json" -Body $body -Headers $headers -Method "PUT"
            if ($response.StatusCode -eq 204) { Write-Host "OK" }
            if ($response.StatusCode > 400)
            {
                Write-Host "ERROR"
                throw [System.Exception] "$($response.StatusCode.ToString()) $($response.StatusDescription)"
            }
        } else {
            "Would update medium_password for node $($node.name)"
        }
    }
}
