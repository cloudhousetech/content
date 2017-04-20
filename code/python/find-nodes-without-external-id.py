#!/usr/bin/env python

import httplib
import urllib
import json
import ssl
import argparse
import re

parser = argparse.ArgumentParser(description='Find any node that does not have an external ID set.')
parser.add_argument('--target-url', required=True, help='URL for the UpGuard instance. This should be the hostname only (appliance.upguard.org instead of https://appliance.upguard.org)')
parser.add_argument('--api-key', required=True, help='API key for the UpGuard instance')
parser.add_argument('--secret-key', required=True, help='Secret key for the UpGuard instance')
parser.add_argument('--insecure', action='store_true', help='Ignore SSL certificate check?')
parser.add_argument('--per-page', type=int, default=100, help='Number of nodes to retrieve in each call. (Default: 100)')
args = parser.parse_args()

# Initializations
browser = None

def getNodes(browser, method, endpoint, page=1, per_page=100):
    """
    Return a JSON-parsed dictionary of nodes
    """
    get_headers = {
        "Authorization": "Token token=\"{}{}\"".format(args.api_key, args.secret_key),
        "Accept": "application/json"}

    browser.request("GET", "{}?page={}&per_page={}".format(endpoint, page, per_page), '', get_headers)
    response = browser.getresponse()
    if response.status >= 400:
        raise httplib.HTTPException("{}: {}".format(str(response.status), str(response.reason)))

    return json.loads(response.read())

try:
    # Setup browser object
    url = args.target_url
    if 'http' in url:
        # URL needs to be a hostname, so remove 'https://'
        url = re.sub('https?:\/\/', '', url)
    browser = httplib.HTTPConnection(url)
    if args.insecure:
        context = ssl._create_unverified_context()
        browser = httplib.HTTPSConnection(url, context=context)

    page = 1
    nodes = getNodes(browser, "GET", "/api/v2/nodes.json", page=page, per_page=args.per_page)
    print "Searching for nodes without an external ID..."
    while nodes:
        for node in nodes:
            if not node['external_id']:
                print "{} (hostname: {})".format(node['name'])

        page += 1
        nodes = getNodes(browser, "GET", "/api/v2/nodes.json", page=page, per_page=args.per_page)

except httplib.HTTPException as h:
    print h.message;
finally:
    if browser:
        browser.close()
