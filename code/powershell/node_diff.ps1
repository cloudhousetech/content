# Ignore self-signed SSL certificates
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


$instance_url = "https://upguard.appliance.url"
$api_key = "<< api_key >>"
$secret_key = "<< service_key >>"
$headers = @{
    'Authorization' = 'Token token="' + $api_key + $secret_key + '"'
    'Accept' = 'application/json'
}

$scan_id = "<< scan_id >>"
$compare_scan_id = "<< compare_scan_id >>"

$node_diff_endpoint = $instance_url + "/api/v2/nodes/diff?scan_id=[scan_id]?compare_scan_id=[compare_scan_id]"

$node_diff_endpoint = $node_diff_endpoint.Replace("[scan_id]", $scan_id)
$node_diff_endpoint = $node_diff_endpoint.Replace("[compare_scan_id]", $compare_scan_id)

$response = Invoke-WebRequest $node_diff_endpoint -Method Get -Headers $headers

if ($response.StatusCode -ge 299) {
    throw [System.Exception] $response.StatusCode.ToString() + " " + $response.StatusDescription
}
else {
    $diff = $response.Content | ConvertFrom-Json
    if ($diff.summary) {
        "Diff Summary Stats"
        "=================="
        $diff.summary
    }
    if ($diff[1]) {
        "Diff Details"
        "============"
        $diff_details = $diff[1]
        $diff_details
    }
    
}
