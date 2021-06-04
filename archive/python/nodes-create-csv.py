#!/usr/bin/python

import csv
import httplib;
import urllib;
import json;
import ssl;

hostname = "your.appliance.hostname"
api_key = "Appliance API Key"
secret_key = "Appliance Secret Key"

def add_node(node):
    # NB: Swap in your custom URL below if you have a dedicated instance
    browser = httplib.HTTPSConnection(hostname, timeout=5, context=ssl._create_unverified_context())
    try:
        body = ''
        for key, val in node.iteritems():
            body += "node[" + urllib.quote_plus(str(key)) + "]=" + urllib.quote_plus(str(val)) + "&"

        body = body[:-1]

        browser.request("POST", "/api/v2/nodes.json", body,
            {"Authorization": "Token token=\"" + api_key + secret_key + "\"",
                "Accept": "application/json",
                "Content-Type": "application/x-www-form-urlencoded"})

        res = browser.getresponse()
        data = res.read()

        if res.status >= 400:
            print str(res.status) + ' ' + res.reason
            raise httplib.HTTPException(str(res.status) + ' ' + res.reason +
                (': ' + data.strip() if data.strip() else ''))

        browser.close()

        if data != '':
            return json.dumps(json.loads(data), sort_keys=True,
                indent=4, separators=(',', ': '))
        else:
            return str(res.status) + res.reason;
    except httplib.HTTPException as h:
        return h.message;
    finally:
        browser.close()

with open("nodes.csv", "rb") as f:
    reader = csv.reader(f)
    node = {}
    for row in reader:
        if row[0] == "node_type":
            # Looks like an empty row or heading row, skip
            continue
        else:
            node['node_type'] = row[0]
            node['medium_type'] = row[1]
            node['medium_username'] = row[2]
            node['medium_password'] = row[3]
            node['medium_port'] = row[4]
            node['connection_manager_group_id'] = row[5]
            node['operating_system_family_id'] = row[6]
            node['operating_system_id'] = row[7]
            node['organisation_id'] = row[8]
            node['environment_id'] = row[9]
            node['name'] = row[10]
            node['medium_hostname'] = row[11]
            node['short_description'] = row[12]
            print "node=" + str(node)
            add_node(node)
