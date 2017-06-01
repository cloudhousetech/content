#!/bin/bash
set -e

# UpGuard parameters
apiKey="<< apiKey >>"
secretKey="<< secretKey >>"
upguard="<< https://your.upguard.appliance >>"
mediumPassword="abc"
alternatePassword="123"
cmGroupId=123
nodeId=123

# UpGuard endpoints
nodesShow="/api/v2/nodes/[0]"

# Headers
combinedKey="$apiKey$secretKey"
authHeader="Authorization: Token token=\"$combinedKey\""
acceptHeader="Accept: application/json"
contentHeader="Content-Type: application/json"

nodesShowReplaced="${nodesShow/\[0\]/$nodeId}"
response=`curl -X PUT -s -k -H "$authHeader" -H "$acceptHeader" -H "$contentHeader" -d '{"node": {"connection_manager_group_id": '\"$cmGroupId\"', "medium_password": '\"$mediumPassword\"', "alternate_password": '\"$alternatePassword\"' }}' $upguard$nodesShowReplaced`
if [[ $response == "" ]]; then
	echo "Updated node password."
else
	echo $response
fi
