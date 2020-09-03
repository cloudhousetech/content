# Delete stale nodes in UpGuard that haven't been scanned in some number of days

import http.client
import urllib
import re
import ssl
import json
import datetime

def getBrowser(target_url, insecure=False):
    url = target_url
    if 'http' in url:
        # URL needs to be a hostname, so remove 'https://'
        url = re.sub('https?:\/\/', '', url)
    browser = http.client.HTTPConnection(url)
    if insecure:
        context = ssl._create_unverified_context()
        browser = http.client.HTTPSConnection(url, context=context)
    return browser

def APICall(browser, token, method, endpoint, body='', params={}):
    """
    Make an API request and return the JSON data response.

    This function uses the built-in http.client library.
    """
    parameters = urllib.parse.urlencode(params) or None
    headers = {
        "Authorization": "Token token=\"{}\"".format(token),
        "Accept": "application/json",
        "Content-Type": "application/json"}
    if parameters:
        endpoint = "{}?{}".format(endpoint, parameters)
    try:
        browser.request(method, endpoint, body, headers)
        response = browser.getresponse()
        data = response.read()

        if response.status == 301:
            raise http.client.HTTPException(
                "Returned {}, try running with `--insecure` argument".format(response.status))
        elif response.status >= 400:
            raise http.client.HTTPException(
                "{} {}\n{}".format(
                    str(response.status),
                    response.reason,
                    (data.strip() if data else 'No Data Returned')))
        return response.status, data
    except http.client.HTTPException as h:
        print(h.message)

def getNodes(browser, token, details=False, group=None):
    """
    Return a list of node objects (by the index endpoint).

    Passing details=True will get all information for each node.

    Alternatively provide a node group (ID or name) to only get those nodes.
    """
    nodes = []
    page = 1
    per_page = 100

    done = False
    while not done:
        status, data = APICall(browser, token, "GET", "/api/v2/nodes.json", params={"page": page, "per_page": per_page})
        new_nodes = json.loads(data)
        nodes += new_nodes
        page += 1
        done = True if len(new_nodes) < per_page else False

    if details:
        detailed_nodes = []
        for node in nodes:
            status, data = APICall(browser, token, "GET", "/api/v2/nodes/{}.json".format(node["id"]))
            detailed_nodes.append(json.loads(data))
        return detailed_nodes
    return nodes

import argparse
import http.client
from datetime import date, timedelta

parser = argparse.ArgumentParser(description='')
parser.add_argument('--target-url', required=True, help='URL for the UpGuard instance')
parser.add_argument('--api-key', required=True, help='API key for the UpGuard instance')
parser.add_argument('--secret-key', required=True, help='Secret key for the UpGuard instance')
parser.add_argument('--dry-run', action='store_true', help='Print which nodes would be deleted without making any changes')
parser.add_argument('--days-old', type=int, default=365, help='If a node hasn\'t been scanned in this number of days, it is deleted')
parser.add_argument('--insecure', action='store_true', help='Ignore SSL certificate checks')
args = parser.parse_args()

browser = getBrowser(target_url=args.target_url, insecure=args.insecure)
token = "{}{}".format(args.api_key, args.secret_key)

# Get all nodes
nodes = getNodes(browser=browser, token=token, details=False)
for node in nodes:
    # Get the date of the last successful scan for this node
    response, data = APICall(browser=browser, token=token, method='GET', endpoint=f'/api/v2/nodes/{node["id"]}/last_successful_scan.json')
    assert response < 400, f'While retrieving last successful scan for {node["name"]}, I received HTTP response {response}'
    last = json.loads(data)
    assert len(last.get('created_at', '').split('T')) > 1, f'Unexpected time format received: {last.get("created_at")}'
    last_scan_date = datetime.datetime.strptime(last.get('created_at').split('T')[0], '%Y-%m-%d').date()

    if last_scan_date < (datetime.date.today() - datetime.timedelta(days=args.days_old)):
        days_old = str(date.today() - last_scan_date).split(',')[0]
        # Delete the node
        if args.dry_run:
            print(f'Would delete {node["name"]} ({days_old} since last scan)')
        else:
            print(f'Deleting {node["name"]} ({days_old} since last scan)')
            response, data = APICall(browser=browser, token=token, method='DELETE', endpoint=f'/api/v2/nodes/{node["id"]}.json')
            assert response < 400, f'While deleting {node["name"]}, I received HTTP response {response}'
