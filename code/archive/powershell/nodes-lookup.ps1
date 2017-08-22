$secret_key = 'secret key goes here'
$api_key = 'api key goes here'
$url = 'appliance.url.here'

$headers = @{'Authorization' = 'Token token="' + $api_key + $secret_key + '"';
                 'Accept' = 'application/json'}

$req = Invoke-WebRequest
    "http://" + $url + "/api/v1/nodes/42/add_to_node_group.json?node_group_id=23"
    -Method "Post" -Headers $headers

if ($req.StatusCode > 400)
{
  throw [System.Exception] $req.StatusCode.ToString() +
    " " + $req.StatusDescription
}
else
{
    $req.Content | ConvertFrom-Json
}