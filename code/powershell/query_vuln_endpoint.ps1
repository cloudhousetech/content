$apiKey = "[enter API key here]"
$secretKey = "[enter secret key here]"
$headers = @{Authorization = 'Token token="' + $apiKey + $secretKey + '"'}

$vulnScanURI = "https://app.upguard.com/api/v2/vulns.json?page="
$counter = 1

do {
    $name = $vulnScanURI + $counter
    $result = Invoke-RestMethod -Method "GET" -Uri $name -Headers $headers
    $counter += 1
    echo $result
}
until($result.length -eq 0)
