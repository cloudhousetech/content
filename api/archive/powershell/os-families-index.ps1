$secret_key = 'secret key goes here'
$api_key = 'api key goes here'
$url = 'appliance.url.here'

$headers = @{'Authorization' = 'Token token="' + $api_key + $secret_key + '"';
                 'Accept' = 'application/json'}

$req = Invoke-WebRequest "http://" + $url + "/api/v1/operating_system_families.json" -Headers $headers

if ($req.StatusCode > 400)
{
  throw [System.Exception] $req.StatusCode.ToString() +
    " " + $req.StatusDescription
}
else
{
    $req.Content | ConvertFrom-Json
}
