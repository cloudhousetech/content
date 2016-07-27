$apiKey = "[enter API key here]"
$secretKey = "[enter secret key here]"
$headers = @{Authorization = 'Token token="' + $apiKey + $secretKey + '"'}

$vulnScanURI = "https://app.upguard.com/api/v2/vulns.json"
Invoke-RestMethod -Method "GET" -Uri $vulnScanURI -Headers $headers
