[System.Net.ServicePointManager]::DefaultConnectionLimit = 1000
# Uncomment if using a self-signed certificate
# [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$global:server = 'companyname.scriptrock.net'
$global:url = "https://" + $server + "/api/v1"
$apiKey = "<api_key>"
$secretKey = "<secret_key>"
$global:headers = @{
  Authorization = 'Token token="' + $apiKey + $secretKey + '"'
}

$MyURI = [System.Uri]$global:url
$ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($MyURI)
$ServicePoint.CloseConnectionGroup("")

function createNode($name)
{
  Write-Host "createNode $name"
  $body = @{
    node = @{
      name = $name;
      medium_hostname = $name;
      node_type = "SV";
      medium_type = 7;
      medium_port = 5985;
      operating_system_family_id = 1;
      connection_manager_group_id = <cm_group_id>;
    }
  } | ConvertTo-json -Depth 5

  Invoke-RestMethod -Method Post -Uri ($global:url + "/nodes.json") -Headers $global:headers -Body $body -ContentType "application/json; charset=utf-8"
}

$names = @( 'node1', 'node2', 'node3' )
foreach	($name in $names) {
  createNode $name
}
