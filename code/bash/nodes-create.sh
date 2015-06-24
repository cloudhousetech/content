#!/bin/bash

curl -w '%{http_code}\n' -X POST -s -k -H "Authorization: Token token=\"abcd1234\"" -H "Accept: application/json" -H "Content-Type: application/json" -d '{"node": {"name": "test", "short_description": "added via api", "node_type": "SV", "operating_system_family_id": 2, "operating_system_id": 221, "medium_type": 3, "medium_username": "username", "medium_hostname": "hostname", "connection_manager_group_id": 1}}' https://hostname/api/v1/nodes
