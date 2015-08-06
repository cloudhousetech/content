Function add_node($node)
{
    $headers = @{
        'Authorization' = 'Token token="ABCD123456EF7890GH"';
    }

    $body = ''
    foreach($kvp in $node["node"].GetEnumerator()) {
	$body += 'node[' + $kvp.Key + ']=' + $kvp.Value + '&'
    }

    $body = $body.TrimEnd('&')

    $body

    # NB: Swap in your custom URL below if you have a dedicated instance
    $req = Invoke-WebRequest "https://guardrail.scriptrock.com/api/v1/nodes.json" -Method POST -Headers $headers -Body $body

    if ($req.StatusCode -ge 400) {
        throw [System.Exception] $req.StatusCode.ToString() + " " +
	$req.StatusDescription
    }

    $req.Content | ConvertFrom-Json
}

foreach ($row in Import-Csv -Header name,nodetype,mediumtype,mediumusername,mediumpassword "nodes.csv")
{
    $node = @{
        "node" = @{
	    "name" = $row.name;
            "node_type" = $row.nodetype;
	    "medium_type" = $row.mediumtype;
	    "medium_username" = $row.mediumusername;
	    "medium_password" = $row.mediumpassword;
            "connection_manager_group_id" = $row.connectionmanagergroupid;
        }
    }
    add_node($node) 
}
