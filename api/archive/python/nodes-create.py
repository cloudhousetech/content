#!/usr/bin/python

import httplib;
import urllib;
import json;

hostname = "guardrail.scriptrock.com"
api_key = "1234..."
secret_key = "5678..."

browser = None

try:
    browser = httplib.HTTPSConnection(hostname)

    node = {
                "name": "host.com",
                "node_type": "SV",
                "medium_type": 3,
                "medium_username": "username",
                "medium_hostname": "hostname",
                "connection_manager_group_id": 1,
            }
    body = ''
    for key, val in node.iteritems():
        body += 'node[' + urllib.quote_plus(str(key)) + ']=' + urllib.quote_plus(str(val)) + '&'

    body = body[:-1]

    browser.request("POST", "/api/v1/nodes.json", body,
        {"Authorization": "Token token=\"" + api_key + secret_key + "\"",
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded"})
    res = browser.getresponse()
    data = res.read()

    if res.status >= 400:
        raise httplib.HTTPException(str(res.status) + ' ' +
            res.reason + (': ' + data.strip() if data.strip() else ''))

    browser.close()

    if data != '':
        print json.dumps(json.loads(data), sort_keys=True,
            indent=4, separators=(',', ': '))
    else:
        print str(res.status) + res.reason;
except httplib.HTTPException as h:
    print h.message;
finally:
    if browser != None:
        browser.close()
