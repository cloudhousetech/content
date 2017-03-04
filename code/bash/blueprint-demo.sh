#!/bin/bash

# Enforce correct script usage (optional).

if [ $# -ne 1 ]; then
  echo $0: usage: blueprint-demo.sh parameter
  exit 1
fi

# The parameter passed down from the website, as specified on the node edit page (optional).

parameter=$1

# If many nodes will be running this script simultaneously, then it's advised to create
# a lock file so that they can form a "queue", avoiding odd EOF errors.

timeout_seconds=120
lockdir=/tmp/$(basename $0).lock

for i in $(seq $timeout_seconds) ; do
    if ! mkdir "$lockdir" 2>/dev/null; then
        if [ "$i" = "$timeout_seconds" ] ; then
            echo "Could not acquire lock directory '$lockdir'" >&2
            exit 2
        else
            sleep 1
        fi
    else
        trap "rm -rf '$lockdir'; exit" INT TERM EXIT
        break
    fi
done

# These are the different ways we can represent configuration items visually in UpGuard.
# It really depends on the how the data looks as to what option you should choose to best display it.
# Making sure configuration is well organised is key. 

# ----- CI names need to be unique. -----

# If you are struggling to make this happen, consider prepending the CI name with an ID or serial number.
# E.g. network_adapter_id_1, network_adapter_id_2, network_adapter_unique_serial_number etc...

# Avoid looping over CIs and adding a number on the end for the given loop. 
# If the CIs happen to rearrange themselves, or the CIs are not ordered, then prepending the loop number will
# make the CIs appear as being different or "changing". E.g.:

# Scan 1

# get ips
# 192.168.0.1, 192.168.0.2

# ci_ip_1
#  - value = 192.168.0.1
# ci_ip_2
#  - value = 192.168.0.2

# Scan 2

# get ips
# 192.168.0.2, 192.168.0.1

# ci_ip_1
#  - value = 192.168.0.2
# ci_ip_2
#  - value = 192.168.0.1

blueprint='{
    "list_view": {
        "ci_1": {
            "attribute_1": "attribute_1_value",
            "attribute_2": "attribute_2_value",
            "attribute_3": "attribute_3_value"
        },
        "ci_2": {
            "attribute_1": "attribute_1_value",
            "attribute_2": "attribute_2_value",
            "attribute_3": "attribute_3_value"
        }
    },
    "various_levels": {
        "level_2_flat": {
            "ci_3": {
                "value": "attribute_1_value"
            },
            "ci_4": {
                "value": "attribute_2_value"
            }
        },
        "level_2_another": {
            "level_3_section_1": {
                "ci_5": {
                    "value": "attribute_1_value"
                },
                "ci_6": {
                    "value": "attribute_1_value"
                }
            },
            "level_3_section_2": {
                "ci_7": {
                    "value": "attribute_1_value"
                },
                "ci_8": {
                    "value": "attribute_1_value"
                }
            }
        }
    },
    "level_1_flat": {
        "hidden_filler_layer": {
            "ci_9": {
                "value": "attribute_1_value"
            },
            "ci_10": {
                "value": "attribute_1_value"
            },
            "ci_11": {
                "value": "attribute_1_value"
            }
        }
    }
}'

echo $blueprint