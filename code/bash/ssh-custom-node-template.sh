#!/bin/bash

device_hostname=$1
device_command=$2
device_output=v1.2.3

blueprint='{
    "facts": {
        "more": {
            "device_hostname": {
                "value": "'$device_hostname'"
            },
            "device_command": {
                "value": "'$device_command'"
            },
            "device_output": {
                "value": "'$device_output'"
            }
        }
    }
}'

echo $blueprint