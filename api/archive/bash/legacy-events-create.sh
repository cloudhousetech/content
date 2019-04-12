#!/bin/bash

# Usage: 
# chmod +x api-timeline.sh
# ./api-timeline.sh -c "Build" -a "Started" -s 2 -i "jira" -d 15 -e "Deploy to production"

while [[ $# > 0 ]]
do
key="$1"

case $key in
    -c|--category)
    CATEGORY="$2"
    shift # past argument
    ;;
    -a|--action)
    ACTION="$2"
    shift
    ;;
    -s|--status)
    STATUS="$2"
    shift
    ;;
    -i|--icon)
    ICON="$2"
    shift
    ;;
    -d|--duration)
    DURATION="$2"
    shift
    ;;    
    -e|--extra)
    EXTRA="$2"
    shift
    ;;
esac
shift
done

data="{\"event\":{\"sub_category\":\"${CATEGORY}\",\"action_taken\":\"${ACTION}\",\"status\":${STATUS},\"source\":\"${ICON}\",\"duration\":\"${DURATION}\",\"extra\":\"${EXTRA}\"}}"
curl -s -k -H "Authorization: Token token=\"abc123\"" -H "Content-Type: application/json" -d "$data" http://hostname/api/v2/legacy_events
