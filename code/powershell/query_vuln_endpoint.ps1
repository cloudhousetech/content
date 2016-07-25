$apiKey = "[enter API key here]"
$secretKey = "[enter secret key here]"
$headers = @{Authorization = 'Token token="' + $apiKey + $secretKey + '"'}

$vulnScanURI = "https://app.upguard.com/api/v2/vulns.json"
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
Invoke-RestMethod -Method "GET" -Uri $vulnScanURI -Headers $headers
