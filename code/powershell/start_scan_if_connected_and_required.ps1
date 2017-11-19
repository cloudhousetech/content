param(
[string]$url='',
[string]$apiKey='',
[string]$secretKey='',
[string]$nodeHostname='',
[int]$interval=12
)

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

function webRequest($requestUrl, $method='GET') {
    $headers = @{Authorization = 'Token token="' + $apiKey + $secretKey + '"'}
    $response = $null

    try {
        $response = Invoke-WebRequest -Uri $requestUrl -Headers $headers -Method $method
    } catch {
        Write-Host $_
    }
    return $response
}


$response = webRequest ($url + '/heartbeat')

if ($response -eq $null -or $response.StatusCode -ne 200) {
    Write-Host "Could not contact $url. Status code: $($response.StatusCode)"
    return
}

Write-Host "Connected to $url successfully. Looking up node"


$response = webRequest ($url + "/api/v2/nodes/lookup.json?name=$nodeHostname") 

if ($response -eq $null -or $response.StatusCode -ne 200) {
    Write-Host "Could not find node via lookup using $nodeHostname"
    return
}

$nodeId = ($response.Content | ConvertFrom-Json)
$nodeId = $nodeId.node_id
$response = $null

Write-Host "Node '$nodeHostname' found via lookup, checking if last successful scan was within 12 hours"

$response =  webRequest ($url + "/api/v2/nodes/$nodeId/last_scan_status.json")

if ($response -eq $null -or $response.StatusCode -ne 200) {
    Write-Host "Could not look up last scan status for node with ID $nodeId"
    return
}

$lastScanDate = [datetime]::ParseExact(($response.Content | ConvertFrom-Json).updated_at,'yyyy-MM-ddTHH:mm:ss.fffzzz', [Globalization.CultureInfo]::InvariantCulture)

if ($lastScanDate -gt (Get-Date).AddHours(-$interval)) {
    Write-Host "Last successful scan less than $interval hours ago ($lastScanDate), exiting"
    return
}

Write-Host "Last scan was more than $interval hours ago, attempting to create scan task"

$response = webRequest ($url + "/api/v2/nodes/$nodeId/start_scan.json") 'Post'


if ($response -eq $null -or $response.StatusCode -ne 201) {
    Write-Host "Failed to start scan for node with ID $nodeId"
    return
}

Write-Host "Started scan job for node with ID $nodeId"