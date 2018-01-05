#!/usr/bin/env python

"""
Pull data from UpGuard event views into json files to be loaded by splunk.

A list of view must be provided, but only one is required.

Examples:

./load-events.py --target-url https://appliance.upguard.org --api-key 123 --secret-key 234 --view "User Logins"

./load-events.py --target-url https://appliance.upguard.org --api-key 123 --secret-key 234 -v "User Logins" -v "Failed Scans"
"""

from __future__ import print_function
import httplib
import urllib
import re
import ssl
import json
import argparse
import time
from datetime import datetime
import os
import sys
import http.client

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
    parameters = urllib.urlencode(params) or None
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
    except http.client.HTTPException as h:
        print(h.message)
    return response.status, data

def getEvents(browser, token, view, since=None):
    """
    Return a list of events using the provided view name

    Optionally provide a datetime.date object in `since` to only return events from a certain date
    """
    events = []
    page = 1
    per_page = 100

    done = False
    while not done:
        status = data = None
        if since:
            status, data = APICall(browser, token, "GET", "/api/v2/events.json", params={"page": page, "per_page": per_page, "view_name": view, "date_from": since.strftime('%Y-%m-%d')})
        else:
            status, data = APICall(browser, token, "GET", "/api/v2/events.json", params={"page": page, "per_page": per_page, "view_name": view})
        new_events = json.loads(data)
        events += new_events
        page += 1
        done = True if len(new_events) < per_page else False
    return events

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Pull data from UpGuard to be used by splunk. "
                    "Each event view will be saved into its own .json file to be loaded by splunk.")
    parser.add_argument('--api-key', required=True, help='The API key for the appliance')
    parser.add_argument('--secret-key', required=True, help='The secret key for the appliance')
    parser.add_argument('--target-url', required=True, help='The URL for the appliance, with no scheme specified')
    parser.add_argument('--insecure', action='store_true', help='Ignore SSL certificate errors')
    parser.add_argument('--since', type=lambda d: datetime.strptime(d, '%Y-%m-%d'), help='Only return events since this date, format YYYY-MM-DD')
    parser.add_argument('-v', '--view', action='append', required=True, help='List of view names to pull from UpGuard')

    args = parser.parse_args()

    browser = None
    try:
        browser = getBrowser(target_url=args.target_url, insecure=args.insecure)
        token = "{}{}".format(args.api_key, args.secret_key)

        # Events
        for view_name in args.view:
            events = getEvents(browser=browser, token=token, view=view_name, since=args.since or None)
            with open("{}.json".format(view_name), 'w') as f:
                print(json.dumps(events, sort_keys=True, indent=4, separators=(',', ': ')), file=f)
            print("Saved {} events to {}.json".format(len(events), view_name))

    except http.client.HTTPException as h:
        print(h.message)
    finally:
        if browser:
            browser.close()
