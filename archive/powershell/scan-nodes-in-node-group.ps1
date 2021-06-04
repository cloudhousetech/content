$apiKey = "[API_KEY]"
$secretKey = "[SECRET_KEY]"
$headers = @{Authorization = 'Token token="' + $apiKey + $secretKey + '"'}
 
 
#Get the list of nodes in the node group
$nodeGroupsURI = "https://[SERVER]/api/v2/node_groups/[NODEGROUPID]/nodes.json"
$nodes = Invoke-RestMethod -Method "GET" -Uri $nodeGroupsURI -Headers $headers
 
#Loop over each node in the group and call start scan
foreach($node in $nodes)
{
    $url = $node.url + "/start_scan.json?label=[LABEL_HERE]"
    Invoke-RestMethod -Method "POST" -Uri $url -Headers $headers
}
