#!/bin/sh
set -e

curl -X POST \
      https://example.upguard.com/api/v2/events.json \
      -H 'Authorization: Token token="<api-key><secret-key>"' \
      -H 'Content-Type: application/json' \
      --data '{ "user_id": 2, "node_id": 123, "variables": { "type": "jenkins deploy" } }'
