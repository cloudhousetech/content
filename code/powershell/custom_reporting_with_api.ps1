$instanceUrl = "https://serverurl.net"
$apiKey = "apiKey"
$secretKey = "secretKey"
$headers = @{
    'Authorization' = 'Token token="' + $apiKey + $secretKey + '"';
}

$cmURL = $instanceUrl + "/api/v2/connection_manager_groups.json"
$envURL = $instanceUrl + "/api/v2/environments.json"
$ngURL = $instanceUrl + "/api/v2/node_groups.json"

# Get all the lists of Nodes, CM Groups, Environments and Node Groups
$connectionManagerGroups = Invoke-RestMethod -Method "GET" -Uri $cmURL -Headers $headers
$environments = Invoke-RestMethod -Method "GET" -Uri $envURL -Headers $headers
$nodeGroups = Invoke-RestMethod -Method "GET" -Uri $ngURL -Headers $headers

# Create Hashtables for CM Groups, Node Groups and Environments with ID and Name

$listConnectionManagers = @{}
$listEnvironment = @{}
$listNodeGroups = @{}

foreach($cm in $connectionManagerGroups) {
	$listConnectionManagers.Add($cm.id, $cm.name)
}

foreach($env in $environments) {
	$listEnvironment.Add($env.id, $env.name)
}

foreach($ng in $nodeGroups) {
	$listNodeGroups.Add($ng.id, $ng.name)
}

# Get Node Data via API

for ($i = 1; $i -le 50; $i++ )
{
  $nodeIndex = $instanceUrl + "/api/v2/nodes.json?page=" + $i + "&per_page=50"
  $nodes +=  Invoke-RestMethod -Method "GET" -Uri $nodeIndex -Headers $headers
}

# Get details for each node and dump data into the CSV

$fullString = "Node Name, Connection Manager Group, Environment, Node Group, External ID" + "`n"

foreach($node in $nodes) {
	$node =  Invoke-RestMethod -Method "GET" -Uri $node.url -Headers $headers

	$cmID = $node.connection_manager_group_id
	$envID = $node.environment_id
	$ngID = $node.primary_node_group_id

  if ($node.name) { $nodeCSV = $node.name + ", "} else {$nodeCSV = "Null Name, "}
  if ($cmID) {$nodeCSV += $listConnectionManagers.Get_Item($cmID) + ", "} else {$nodeCSV += "null, "}
  if ($envID) {$nodeCSV += $listEnvironment.Get_Item($envID) + ", "} else {$nodeCSV += "null, "}
  if ($ngID) {$nodeCSV += $listNodeGroups.Get_Item($ngID) + ", "} else {$nodeCSV += "null, "}
  if ($node.external_id) {$nodeCSV += $node.external_id + "`n"} else {$nodeCSV += "null" + "`n"}

	$fullString += $nodeCSV
}

$fullString | Set-Content 'export.csv'
