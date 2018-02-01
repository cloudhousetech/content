#!/usr/bin/env python

from __future__ import print_function

import argparse
import http.client
from snippets import getBrowser, APICall, getNodes, getNodeGroups, getConnectionManagerGroups, getNodesInCMGroups, getPolicies, getEvents, scan
from datetime import date, timedelta

parser = argparse.ArgumentParser(description='')
parser.add_argument('--target-url', required=True, help='URL for the UpGuard instance')
parser.add_argument('--api-key', required=True, help='API key for the UpGuard instance')
parser.add_argument('--secret-key', required=True, help='Secret key for the UpGuard instance')
parser.add_argument('--insecure', action='store_true', help='Ignore SSL certificate checks')
args = parser.parse_args()

try:
    browser = getBrowser(target_url=args.target_url, insecure=args.insecure)
    token = "{}{}".format(args.api_key, args.secret_key)

    # Nodes
    nodes = getNodes(browser=browser, token=token, details=True)
    print("\n\nNodes\n-----")
    for node in nodes:
        print("{}\n{}\n\n".format(node["name"], node))

    # Node Groups
    node_groups = getNodeGroups(browser=browser, token=token, details=True)
    print("\n\nNode Groups\n-----")
    for group in node_groups:
        print("{}\n{}\n\n".format(group["name"], group))

    # CM Groups
    cm_groups = getConnectionManagerGroups(browser=browser, token=token)
    print("\n\nConnection Manager Groups\n-------------------------")
    for group in cm_groups:
        print("{}\n{}\n\n".format(group["name"], group))

    # CM Groups with Nodes
    cm_groups = getConnectionManagerGroups(browser=browser, token=token)
    cm_groups_with_nodes = getNodesInCMGroups(browser=browser, token=token)
    print("\n\nCM Groups Node Count\n--------------------")
    for id, nodes in cm_groups_with_nodes.iteritems():
        group_name = next((g["name"] for g in cm_groups if g["id"] == id), None)
        print("{}: {}".format(group_name, len(nodes)))

    # Policies
    policies = getPolicies(browser=browser, token=token, details=True)
    print("\n\nPolicies\n--------")
    for policy in policies:
        print("{}\n{}\n\n".format(policy["name"], policy))

    # Events
    events = getEvents(browser=browser, token=token, view="User Logins", since=(date.today() - timedelta(1)))
    print("\n\nEvents\n-----")
    for event in events:
        print("{}\n{}\n\n".format(event["id"], event))
    print("Total Events: {}".format(len(events)))

    # Scan
    result = scan(browser=browser, token=token, node="dev", wait=True)
    print("Node scanned, result:\n{}".format(str(result)))

except http.client.HTTPException as h:
    print(h.message)
finally:
    if browser:
        browser.close()
