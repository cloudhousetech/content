#!/bin/bash
set -e

# UpGuard parameters
apiKey="abcd"
secretKey="1234"
upguard="https://appliance.url"
linuxConnectionManagerGroupId=1
linuxNodeOSFamily=2 # Linux
ubuntuNodeOS=231 # Centos
nodeIPHostname=$(hostname -f)
manifestDesc="Logoff%20script"

# UpGuard endpoints
nodes="/api/v2/nodes"
nodesLookup="/api/v2/nodes/lookup.json?external_id=[0]"
nodesScan="/api/v2/nodes/[0]/start_scan.json?label=[1]"

# Headers
combinedKey="$apiKey$secretKey"
authHeader="Authorization: Token token=\"$combinedKey\""
acceptHeader="Accept: application/json"
contentHeader="Content-Type: application/json"

# Check to see if the node has already been added to UpGuard.
nodesLookupReplaced="${nodesLookup/\[0\]/$nodeIPHostname}"
nodeIdResponse=`curl -X GET -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" $upguard$nodesLookupReplaced`

if [[ $nodeIdResponse == *"node_id"* ]]; then
	# It's already here.
	nodeId=`echo $nodeIdResponse | perl -ne 'if ( /\"node_id\":(\d+)\b/ ) { print "$1"; }'`
else
	# Not here, need to create it.
	nodeIdResponse=`curl -X POST -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" -d '{"node": {"name": '\"$nodeIPHostname\"', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": '$linuxNodeOSFamily', "operating_system_id": '$ubuntuNodeOS', "medium_type": 3, "medium_port": 22, "connection_manager_group_id": '$linuxConnectionManagerGroupId', "medium_hostname": '\"$nodeIPHostname\"', "external_id": '\"$nodeIPHostname\"' }}' $upguard$nodes`
	nodeId=`echo $nodeIdResponse | perl -ne 'if ( /\"id\":(\d+)\b/ ) { print "$1"; }'`
fi

if [ -n "$nodeId" ]; then
	# Kick off a node scan.
	nodesScanReplaced="${nodesScan/\[0\]/$nodeId}"
	nodesScanReplaced="${nodesScanReplaced/\[1\]/$manifestDesc}"
	startScanResponse=`curl -L -w '%{http_code}\n' -X POST -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" $upguard$nodesScanReplaced`
	jobId=`echo $startScanResponse | perl -ne 'if ( /\"job_id\":(\d+)\b/ ) { print "$1"; }'`
else
	echo "upguard: unable to find or create node to scan"
fi

if [ -n "$jobId" ]; then
	echo "upguard: node scan kicked off against "$nodeIPHostname" ("$upguard"/jobs/"$jobId"/show_job?show_all=true)"
else
	echo "upguard: unable to start a node scan"
fi



