#!/bin/bash
set -e

# UpGuard parameters
apiKey="abc"
secretKey="123"
combinedKey="$apiKey$secretKey"
upguard="https://appliance.upguard.com"
authHeader="Authorization: Token token=\"$combinedKey\""
acceptHeader="Accept: application/json"
contentHeader="Content-Type: application/json"
linuxConnectionManagerGroupId=1
windowsConnectionManagerGroupId=2

# UpGuard endpoints
nodes="/api/v2/nodes"
nodesLookup="/api/v2/nodes/lookup.json?external_id=[0]"
nodesScan="/api/v2/nodes/[0]/start_scan.json?label=[1]"

# Puppet parameters (configured node inventory/facts)
windowsNodeOSFamily=1
windows2012NodeOS=125
linuxNodeOSFamily=2
ubuntuNodeOS=221
windows2012=true
nodeAlias="alias"
nodeIPHostname="127.0.0.1"
manifestDesc='Deploy%20x%20package'

# Check to see if the node has already been added to UpGuard.
nodesLookupReplaced="${nodesLookup/\[0\]/$nodeIPHostname}"
nodeIdResponse=`curl -X GET -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" $upguard$nodesLookupReplaced`

if [[ $nodeIdResponse == *"node_id"* ]]; then
	# It's already here.
	nodeId=`echo $nodeIdResponse | perl -ne 'if ( /\"node_id\":(\d+)\b/ ) { print "$1"; }'`
else
	# Not here, need to create it. Creation is different for Windows vs SSH nodes.
	if [ $windows2012 ]; then
		nodeIdResponse=`curl -X POST -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" -d '{"node": {"name": '\"$nodeAlias\"', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": '$windowsNodeOSFamily', "operating_system_id": '$windows2012NodeOS', "medium_type": 7, "medium_port": 5985, "connection_manager_group_id": '$windowsConnectionManagerGroupId', "medium_hostname": '\"$nodeIPHostname\"', "external_id": '\"$nodeIPHostname\"' }}' $upguard$nodes`
	else
		nodeIdResponse=`curl -X POST -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" -d '{"node": {"name": '\"$nodeAlias\"', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": '$linuxNodeOSFamily', "operating_system_id": '$ubuntuNodeOS', "medium_type": 3, "medium_port": 22, "connection_manager_group_id": '$linuxConnectionManagerGroupId', "medium_hostname": '\"$nodeIPHostname\"', "external_id": '\"$nodeIPHostname\"' }}' $upguard$nodes`
	fi
	nodeId=`echo $nodeIdResponse | perl -ne 'if ( /\"id\":(\d+)\b/ ) { print "$1"; }'`
fi

if [ -n "$nodeId" ]; then
	# Kick off a node scan.
	nodesScanReplaced="${nodesScan/\[0\]/$nodeId}"
	nodesScanReplaced="${nodesScanReplaced/\[1\]/\"$manifestDesc\"}"
	startScanResponse=`curl -w '%{http_code}\n' -X POST -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" $upguard$nodesScanReplaced`
	jobId=`echo $startScanResponse | perl -ne 'if ( /\"job_id\":(\d+)\b/ ) { print "$1"; }'`
else
	echo "{\"error\": \"unable to find or create node to scan\"}"
fi

if [ -n "$jobId" ]; then
	echo "{\"success\": \"node scan kicked off against "$nodeIPHostname" ("$upguard"/jobs/"$jobId"/show_job?show_all=true)\"}"
else
	echo "{\"error\": \"unable to start a node scan\"}"
fi



