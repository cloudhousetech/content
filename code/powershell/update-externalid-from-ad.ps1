# For all nodes in UpGuard, update the external id by pulling the LDAP DN from AD
# You will be prompted for credentials to query AD

param (
    [string]$ApiKey = '',
    [string]$SecretKey = '',
    [string]$Url = 'https://',
    [string]$DomainController = '',
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

$creds = (Get-Credential)

$headers = @{'Authorization' = "Token token=""$($ApiKey)$($SecretKey)""";
                 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

$nodes = Invoke-WebRequest -Uri "https://$($Url)/api/v2/nodes.json?page=1&per_page=50000" -Headers $headers -Method "GET"

if ($nodes.StatusCode > 400)
{
  throw [System.Exception] "$($nodes.StatusCode.ToString()) $($nodes.StatusDescription)"
}
else
{
    $nodes = ConvertFrom-Json -InputObject $nodes

    ForEach ($node in $nodes)
    {
        # Need to perform an additional lookup to get detailed node information.
        $node_details = Invoke-WebRequest -Uri "https://$($Url)/api/v2/nodes/$($node.id).json" -Headers $headers -Method "GET"
        $node_details = ConvertFrom-Json -InputObject $node_details

        $dn = Get-ADComputer -Identity "$($node_details.name)" -Credential $creds -Server $DomainController
        $external_id = "LDAP://$($dn.DistinguishedName)"

        if ($DryRun -eq $false)
        {
            "Updating node $($node_details.name) external id to $($external_id)"
            $body = @{"node" = @{"external_id" = $external_id}}
            $body = ConvertTo-Json -InputObject $body
            $response = Invoke-WebRequest -Uri "https://$($Url)/api/v2/nodes/$($node.id).json" -Body $body -Headers $headers -Method "PUT"
            if ($response.StatusCode > 400)
            {
                throw [System.Exception] "$($response.StatusCode.ToString()) $($response.StatusDescription)"
            }
        } else {
            "Would update node $($node_details.name) external id to $($external_id)"
        }
    }
}
