#!/usr/bin/python

import httplib
import urllib
import json
import ssl
import argparse

parser = argparse.ArgumentParser(description='Set each node\'s hostname to its display name')
parser.add_argument('--target_url', required=True, help='URL for the UpGuard instance. This should be the hostname only (appliance.upguard.org instead of https://appliance.upguard.org)')
parser.add_argument('--api_key', required=True, help='API key for the UpGuard instance')
parser.add_argument('--secret_key', required=True, help='Secret key for the UpGuard instance')
parser.add_argument('--prefix', default='', help='Optional prefix to add to hostname')
parser.add_argument('--suffix', default='', help='Optional suffix to add to hostname')
parser.add_argument('--username', default='', help='Optional username to use for each node')
parser.add_argument('--dry-run', action='store_true', help='See changes that would be made without committing')
args = parser.parse_args()

# Initializations
browser = None

try:
    if args.dry_run:
        print "Dry Run enabled, no changes will be made"
    browser = httplib.HTTPConnection(args.target_url)
    context = ssl._create_unverified_context()
    browser = httplib.HTTPSConnection(args.target_url, context=context)
    get_headers = {"Authorization": 'Token token="' + args.api_key + args.secret_key + '"',
    "Accept": "application/json"}
    browser.request("GET", "/api/v2/nodes.json?page=1&per_page=500", '', get_headers)
    get_res = browser.getresponse()
    nodeList = get_res.read()
    browser.close()

    if get_res.status >= 400:
        raise httplib.HTTPException(str(get_res.status) + ' ' +
            get_res.reason + (': ' + nodeList.strip() if nodeList.strip() else ''))

    if nodeList != '':
        nodeListJson = json.loads(nodeList)
        print "Found {} nodes".format(str(len(nodeListJson)))
        count = 1
        for node in nodeListJson:
            node_id = node['id']

            browser.request("GET", "/api/v2/nodes/" + str(node_id), '', get_headers)
            get_res = browser.getresponse()
            nodeDetail = get_res.read()
            browser.close()

            if get_res.status >= 400:
                raise httplib.HTTPException(str(get_res.status) + ' ' +
                    get_res.reason + (': ' + nodeDetail.strip() if nodeDetail.strip() else ''))

            if nodeDetail != '':
                nodeDetailJson = json.loads(nodeDetail)

                medium_hostname = args.prefix + nodeDetailJson['name'] + args.suffix
                medium_username = args.username

                output = {'node' : { 'medium_hostname' : medium_hostname}}
                if medium_username:
                    output['node']['medium_username'] = medium_username
                body = json.dumps(output)

                print "Updating {} to {} ({}/{})".format(
                    nodeDetailJson['name'], medium_hostname, str(count), str(len(nodeListJson)))

                if args.dry_run is False:
                    put_headers = {"Authorization": 'Token token="' + args.api_key + args.secret_key + '"',
                    "Accept": "application/json", 'Content-Type':'application/json'}
                    browser.request("PUT", "/api/v2/nodes/" + str(node_id) +".json", body, put_headers)
                    update_res = browser.getresponse()
                    browser.close();

                    if update_res.status >= 400:
                        raise httplib.HTTPException(str(update_res.status) + ' ' +
                            update_res.reason + (': ' + data.strip() if data.strip() else ''))

            count = count + 1

except httplib.HTTPException as h:
    print h.message;
finally:
    if browser:
        browser.close()
