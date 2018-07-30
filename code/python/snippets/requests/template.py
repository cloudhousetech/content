#!/usr/bin/env python

from __future__ import print_function

import argparse
import sys
from snippets import getSession, getNodes, getNodeGroups, getConnectionManagerGroups, getNodesInCMGroups, getPolicies, getEvents, scan
from datetime import date, timedelta

parser = argparse.ArgumentParser(description='')
parser.add_argument('--target-url', required=True, help='URL for the UpGuard instance')
parser.add_argument('--api-key', required=True, help='API key for the UpGuard instance')
parser.add_argument('--secret-key', required=True, help='Secret key for the UpGuard instance')
parser.add_argument('--insecure', action='store_true', help='Ignore SSL certificate checks')
args = parser.parse_args()

session = getSession(
    api_key=args.api_key,
    secret_key=args.secret_key,
    insecure=args.insecure)

# Nodes
nodes = getNodes(session=session, url=args.target_url, details=False)
print("\n\nNodes\n-----")
# for node in nodes:
#     print("{}\n{}\n\n".format(node["name"], node))
print("{} total".format(len(nodes)))

# Node Groups
node_groups = getNodeGroups(session=session, url=args.target_url, details=True)
print("\n\nNode Groups\n-----")
for group in node_groups:
    print("{}\n{}\n\n".format(group["name"], group))
print("{} total".format(len(node_groups)))

# CM Groups
cm_groups = getConnectionManagerGroups(session=session, url=args.target_url)
print("\n\nConnection Manager Groups\n-------------------------")
for group in cm_groups:
    print("{}\n{}\n\n".format(group["name"], group))
print("{} total".format(len(cm_groups)))

# CM Groups with Nodes
cm_groups = getConnectionManagerGroups(session=session, url=args.target_url)
cm_groups_with_nodes = getNodesInCMGroups(session=session, url=args.target_url)
print("\n\nCM Groups Node Count\n--------------------")
for id, nodes in cm_groups_with_nodes.iteritems():
    group_name = next((g["name"] for g in cm_groups if g["id"] == id), None)
    print("{}: {}".format(group_name, len(nodes)))

# Policies
policies = getPolicies(session=session, url=args.target_url, details=True)
print("\n\nPolicies\n--------")
print(str(policies))
for policy in policies:
    print("{}\n{}\n\n".format(policy["name"], policy))
print("{} total".format(len(policies)))

# Events
events = getEvents(session=session, url=args.target_url, view="User Logins", since=(date.today() - timedelta(1)))
print("\n\nEvents\n-----")
# for event in events:
#     print("{}\n{}\n\n".format(event["id"], event))
print("Total Events: {}".format(len(events)))

# Scan
result = scan(session=session, url=args.target_url, node="dev", wait=True)
print("Node scanned, result:\n{}".format(str(result)))

# Add Node
# Commented fields are optional
# Description for each field can be found at the commented URL
node = {
    "name": "",
    # "mac_address": "",
    "node_type": "SV", # From https://support.upguard.com/upguard/nodes-api-v2.html#node-types
    "environment_id": 0, # https://support.upguard.com/upguard/bulk-add-nodes.html#environment-id
    "operating_system_family_id": 0, # https://support.upguard.com/upguard/bulk-add-nodes.html#operating-system-family-id
    "operating_system_id": 0, # https://support.upguard.com/upguard/bulk-add-nodes.html#operating-system-id
    "medium_type": 0, # From https://support.upguard.com/upguard/nodes-api-v2.html#medium-types
    # "medium_username": "", # https://support.upguard.com/upguard/bulk-add-nodes.html#medium-username
    "medium_hostname": "", # https://support.upguard.com/upguard/bulk-add-nodes.html#medium-hostname
    # "medium_port": "", # https://support.upguard.com/upguard/bulk-add-nodes.html#medium-port
    # "medium_password": "", # https://support.upguard.com/upguard/bulk-add-nodes.html#medium-password
    # "external_id": "", # https://support.upguard.com/upguard/bulk-add-nodes.html#external-id
    "connection_manager_group_id": 0, # https://support.upguard.com/upguard/bulk-add-nodes.html#connection-manager-group-id
    # "short_description":  # https://support.upguard.com/upguard/bulk-add-nodes.html#short-description
}
print("\n\nAdding node '{}'...".format(node["name"]))
result = addNode(session=session, url=getUrl(args.target_url), node=node, verify=(not args.insecure))
print(result)
