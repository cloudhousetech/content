$apiKey = "1234"
$secretKey = "5678"

$node = @{
    'name' = 'host.com';
    'node_type' = 'SV';
    'medium_type' = 3;
    'medium_username' = 'username';
    'medium_hostname' = 'hostname';
    'medium_port' = 22;
    'connection_manager_group_id' = 1
}


$headers = @{
    'Authorization' = 'Token token="' + $apiKey + $secretKey + '"';
}

$body = ''
foreach($kvp in $node.GetEnumerator()) {
    $body += 'node[' + $kvp.Key + ']=' + $kvp.Value + '&'
}

$body = $body.TrimEnd('&')

$req = Invoke-WebRequest "http://localhost:3000/api/v1/nodes.json" -Method Post -Headers $headers -Body $body

if ($req.StatusCode -ge 400) {
    throw [System.Exception] $req.StatusCode.ToString() +
    " " + $req.StatusDescription
}
else {
    $req.Content | ConvertFrom-Json
}
