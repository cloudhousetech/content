#!/usr/bin/python

import csv
import httplib;
import urllib;
import json;

def add_node(node):
    # NB: Swap in your custom URL below if you have a dedicated instance
    browser = httplib.HTTPConnection('guardrail.scriptrock.com')
    try:
        body = ''
        for key, val in node.iteritems():
            body += 'node[' + urllib.quote_plus(str(key)) + ']=' +
                urllib.quote_plus(str(val)) + '&'

        body = body[:-1]

        browser.request('POST', '/api/v1/nodes.json', body,
            {'Authorization': 'Token token="ABCD123456EF7890GH"',
                'Accept': 'application/json',
                'Content-Type':'application/x-www-form-urlencoded'})
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

with open('nodes.csv', 'rb') as f:
    reader = csv.reader(f)
    node = {}
    for row in reader:
        node['name'] = row[0]
        node['node_type'] = row[1]
        node['medium_type'] = row[2]
        node['medium_username'] = row[3]
        node['medium_password'] = row[4]
        node['connection_manager_group_id'] = row[5]
        add_node(node)
