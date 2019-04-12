param(
[string]$url='',
[string]$apiKey='',
[string]$secretKey='',
[string]$file=''
)

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

function webRequest($requestUrl, $method='GET', $body=$null) {
    $headers = @{Authorization = 'Token token="' + $apiKey + $secretKey + '"'}
    $response = $null

    try {
        Write-Host (@{ 'node' = $body } | ConvertTo-JSON)
        $response = Invoke-WebRequest -Uri $requestUrl -Headers $headers -Method $method -Body (@{ 'node' = $body } | ConvertTo-Json) -ContentType 'application/json'
    } catch {
        Write-Host $_
    }
    return $response
}

$index = 0

Import-Csv $file | ForEach-Object {
    $body = @{}
    $row = $_
    $row | Get-Member -MemberType NoteProperty | ForEach-Object {
        $body[$_.Name] = $row."$($_.Name)"
    }

    $response = webRequest ($url + "/api/v2/nodes.json") 'Post' $body
    
    if ($response -eq $null -or $response.StatusCode -gt 299) {
        Write-Host "Failed to upload row $($index), response code was: $($response.StatusCode)"
    }

    $index++
}