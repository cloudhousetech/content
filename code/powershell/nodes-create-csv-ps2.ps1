$apiKey = "YOUR API KEY HERE"
$secretKey = "YOUR SECRET KEY HERE"
$token = $apiKey + $secretKey
$headerPart1 = 'Authorization'
$headerPart2 = 'Token token="' + $token + '"'
# NB: Swap in your custom URL below if you have a dedicated instance
$uri = "https://guardrail.scriptrock.com/api/v1/nodes"
$version = $PSVersionTable.PSVersion.Major
 
function add_node($node) {
    $body = ''
    foreach($kvp in $node["node"].GetEnumerator()) {
	   $body += 'node[' + $kvp.Key + ']=' + $kvp.Value + '&'
    }

    $body = $body.TrimEnd('&')
    $enc = [system.Text.Encoding]::UTF8
    $bodyBytes = $enc.GetBytes($body) 

    # PowerShell 2.0 way
    $request = [System.Net.HTTPWebRequest]::Create($uri)
    $request.Method="Post"
    $request.ContentType = "application/json"
    $request.Headers.Set($headerPart1, $headerPart2)
    $request.ContentType = "application/x-www-form-urlencoded"
    $request.Accept = "application/json"
    
    $dataStream = $request.GetRequestStream()
    $dataStream.Write($bodyBytes, 0, $bodyBytes.Length)    
    $dataStream.Close()
 
    $requestStream = $request.GetResponse().GetResponseStream()
    $readStream = New-Object System.IO.StreamReader $requestStream
    $data = $readStream.ReadToEnd()
    $readStream.Dispose();
    $readStream.Close();
 
    # The loading of this dll assumes that even though you are on PowerShell 2.0 you have .NET 3.5 installed
    [System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    $serialization = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $results = $serialization.DeserializeObject($data)
    return $results
}
 
foreach ($row in Import-Csv -Header name,nodetype,mediumtype,mediumhostname,mediumusername,mediumpassword,mediumport,connectionmanagergroupid,operatingsystemfamilyid,operatingsystemid "nodes.csv")
{
    $node = @{
        "node" = @{
            "name" = $row.name;
            "node_type" = $row.nodetype;
            "medium_type" = $row.mediumtype;
            "medium_hostname" = $row.mediumhostname;	        
            "medium_username" = $row.mediumusername;
            "medium_password" = $row.mediumpassword;
            "medium_port" = $row.mediumport;
            "connection_manager_group_id" = $row.connectionmanagergroupid;
            "operating_system_family_id" = $row.operatingsystemfamilyid;
            "operating_system_id" = $row.operatingsystemid;
        }
    }
    add_node($node)
}
