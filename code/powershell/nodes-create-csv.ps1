$apiKey = "YOUR SERVICE API KEY"
$secretKey = "YOUR SECRET KEY"
$uri = "https://guardrail.scriptrock.com/api/v1/nodes"
$csvFileLocation = "C:\location\to\nodes.csv"
$token = $apiKey + $secretKey

Function add_node($node)
{
    try {
        $headers = @{
            'Authorization' = 'Token token="' + $token + '"'
            'Accept' = 'application/json'
        }

        $body = ''
        foreach($kvp in $node["node"].GetEnumerator()) {
	        $body += 'node[' + $kvp.Key + ']=' + $kvp.Value + '&'
        }
        $body = $body.TrimEnd('&')
        $body

        $req = Invoke-WebRequest $uri -Method POST -Headers $headers -Body $body
        $req.Content | ConvertFrom-Json

    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $_.Exception.Response
            $bodyStream = $_.Exception.Response.GetResponseStream()
            $bodyReader = New-Object System.IO.StreamReader($bodyStream)
            $bodyReader.BaseStream.Position = 0
            $bodyReader.DiscardBufferedData()
            $bodyReader.ReadToEnd()
        } else { # e.g. SSL errors
            $_.Exception.Message
        }
    } catch {
        $_.Exception.Message
    }
}

foreach ($row in Import-Csv -Header name,nodetype,mediumtype,mediumhostname,mediumusername,mediumpassword,mediumport,connectionmanagergroupid,operatingsystemfamilyid,operatingsystemid $csvFileLocation)
{
    $node = @{
        "node" = @{
            "name" = $row.name
            "node_type" = $row.nodetype
            "medium_type" = $row.mediumtype
            "medium_hostname" = $row.mediumhostname	        
            "medium_username" = $row.mediumusername
            "medium_password" = $row.mediumpassword
            "medium_port" = $row.mediumport
            "connection_manager_group_id" = $row.connectionmanagergroupid
            "operating_system_family_id" = $row.operatingsystemfamilyid
            "operating_system_id" = $row.operatingsystemid
        }
    }
    add_node($node)
}
