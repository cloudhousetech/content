param(
[string]$url='',
[string]$apiKey='',
[string]$secretKey='',
[string]$nodeHostname='',
[int]$interval=12
)

Set-Variable ERR_SUCCESS -option Constant -value 0
Set-Variable ERR_NO_UPGUARD_SERVICE -option Constant -value 1
Set-Variable ERR_UPGUARD_SERVICE_STOPPED -option Constant -value 2
Set-Variable ERR_NO_HEARTBEAT -option Constant -value 3
Set-Variable ERR_NODE_NOT_FOUND -option Constant -value 4
Set-Variable ERR_LAST_STATUS_NOT_FOUND -option Constant -value 5
Set-Variable ERR_COULD_NOT_START_SCAN -option Constant -value 6

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


Write-Host "Checking that the UpGuard service is running"

$service = $null

try {
    $service = Get-Service -Name 'upguardd'
} catch {
    Write-Host $_
    exit $ERR_NO_UPGUARD_SERVICE
}

if ($service -eq $null) {
    Write-Host 'Could not find upguardd service, exiting'
    exit $ERR_NO_UPGUARD_SERVICE
}

if ($service.Status -ne 'Running') {
    Write-Host 'upguardd service is not running, attempting to start'
    $service.Start();
    try {
        $service.WaitForStatus('Running', '00:00:10')
    } catch {
        Write-Host 'The upguardd service did not start within 10 seconds, exiting'
        Write-Host $_
        exit $ERR_UPGUARD_SERVICE_STOPPED
    }
}

Write-Host 'Service is running, confirming connectivity to UpGuard appliance'

$response = webRequest ($url + '/heartbeat')

if ($response -eq $null -or $response.StatusCode -ne 200) {
    Write-Host "Could not contact $url. Status code: $($response.StatusCode)"
    exit $ERR_NO_HEARTBEAT
}

Write-Host "Connected to $url successfully. Looking up node"


$response = webRequest ($url + "/api/v2/nodes/lookup.json?name=$nodeHostname") 

if ($response -eq $null -or $response.StatusCode -ne 200) {
    Write-Host "Could not find node via lookup using $nodeHostname"
    exit $ERR_NODE_NOT_FOUND
}

$nodeId = ($response.Content | ConvertFrom-Json)
$nodeId = $nodeId.node_id
$response = $null

Write-Host "Node '$nodeHostname' found via lookup, checking if last successful scan was within 12 hours"

$response =  webRequest ($url + "/api/v2/nodes/$nodeId/last_scan_status.json")

if ($response -eq $null -or $response.StatusCode -ne 200) {
    Write-Host "Could not look up last scan status for node with ID $nodeId"
    exit $ERR_LAST_STATUS_NOT_FOUND
}

$lastScanDate = [datetime]::ParseExact(($response.Content | ConvertFrom-Json).updated_at,'yyyy-MM-ddTHH:mm:ss.fffzzz', [Globalization.CultureInfo]::InvariantCulture)

if ($lastScanDate -gt (Get-Date).AddHours(-$interval)) {
    Write-Host "Last successful scan less than $interval hours ago ($lastScanDate), exiting"
    exit $ERR_SUCCESS
}

Write-Host "Last scan was more than $interval hours ago, attempting to create scan task"

$response = webRequest ($url + "/api/v2/nodes/$nodeId/start_scan.json") 'Post'


if ($response -eq $null -or $response.StatusCode -ne 201) {
    Write-Host "Failed to start scan for node with ID $nodeId"
    exit $ERR_COULD_NOT_START_SCAN
}

Write-Host "Started scan job for node with ID $nodeId"