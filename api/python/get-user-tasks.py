#!/usr/bin/env python

import httplib
import json
import argparse
import re
import ssl

parser = argparse.ArgumentParser(description='Retrieve a list of open User Tasks and their associated nodes')
parser.add_argument('--target-url', required=True, help='URL for the UpGuard instance')
parser.add_argument('--api-key', required=True, help='API key for the UpGuard instance')
parser.add_argument('--secret-key', required=True, help='Secret key for the UpGuard instance')
parser.add_argument('--insecure', action='store_true', help='Ignore SSL certificate checks')

args = parser.parse_args()

def setupBrowser():
    url = args.target_url
    if 'http' in url:
        # URL needs to be a hostname, so remove 'https://'
        re.sub('https?:\/\/', '', url)
    browser = httplib.HTTPConnection(url)
    if args.insecure:
        context = ssl._create_unverified_context()
        browser = httplib.HTTPSConnection(url, context=context)
    return browser

def APICall(browser, method, endpoint):
    try:
        browser.request("GET", "/api/v2/user_tasks.json", '',
            {"Authorization": 'Token token="' + args.api_key + args.secret_key + '"',
            "Accept": "application/json"})
        res = browser.getresponse()
        # read() must be called before close(), or it will return an empty string
        data = res.read()

        if res.status == 301:
            raise httplib.HTTPException(
                "Returned {}, try running with `--insecure` argument".format(res.status))
        elif res.status >= 400:
            raise httplib.HTTPException(
                "{} {}\n{}".format(
                    str(res.status),
                    res.reason,
                    (data.strip() if data else 'No Data Returned')))
    except httplib.HTTPException as h:
        print h.message
    return res.status, data

# Initialization
url = args.target_url
if 'http' in url:
    # URL needs to be a hostname, so remove 'https://'
    re.sub('https?:\/\/', '', url)

browser = setupBrowser()

try:

    if args.insecure:
        context = ssl._create_unverified_context()
        browser = httplib.HTTPSConnection(url, context=context)
    browser.request("GET", "/api/v2/user_tasks.json", '',
        {"Authorization": 'Token token="' + args.api_key + args.secret_key + '"',
        "Accept": "application/json"})
    res = browser.getresponse()
    # read() must be called before close(), or it will return an empty string
    data = res.read()

    if res.status == 301:
        raise httplib.HTTPException(
            "Returned {}, try running with `--insecure` argument".format(res.status))
    elif res.status >= 400:
        raise httplib.HTTPException(
            "{} {}\n{}".format(
                str(res.status),
                res.reason,
                (data.strip() if data else 'No Data Returned')))

    browser.close()

    if data != '':
        for i in json.loads(data):
            if i['status'] == 2:
                # Task is closed, move on
                continue

            if i['source_type'] == 1:
                # Policy Failure
                pass
            elif i['source_type'] == 2:
                # Scan Failure
                pass
            elif i['source_type'] == 3:
                # Drift Detected
                pass
            elif i['source_type'] == 4:
                # Target Offline
                pass

            print "\n---\n{}: {}\nNodes:\n  - {}".format(
                i['id'], i['description'], "\n  - ".join(i['nodes']) or "None")
    else:
        print str(res.status) + res.reason
except httplib.HTTPException as h:
    print h.message
finally:
    browser.close()
