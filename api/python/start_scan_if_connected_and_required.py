#!/usr/bin/python3

import csv
import http.client
import urllib
import json
import argparse
import ssl
import os
import datetime

ERR_SUCCESS                     = 0
ERR_NO_UPGUARD_SERVICE          = 1
ERR_UPGUARD_SERVICE_STOPPED     = 2
ERR_NO_HEARTBEAT                = 3
ERR_NODE_NOT_FOUND              = 4
ERR_LAST_STATUS_NOT_FOUND       = 5
ERR_COULD_NOT_START_SCAN        = 6

class Utils:
    def __init__(self, debug_mode=False):
        self.debug_mode = debug_mode

    def debug_print(self, obj):
        if self.debug_mode:
            print(obj)

    def pretty_print_object(self, obj):
        print(json.dumps(obj, sort_keys=True, indent=4, separators=(',', ': ')))

class API:
    def __init__(self, api_key, secret_key, url, utils, use_http=False, unverified_context=False):
        self.api_key = api_key
        self.secret_key = secret_key
        self.url = url
        self.utils = utils
        self.use_http = use_http
        self.unverified_context = unverified_context

    def auth_token(self, api_key, secret_key):
        return {'Authorization': 'Token token="' + api_key + secret_key + '"'}

    def append_auth_token_to_headers(self, headers):
        headers['Authorization'] = self.auth_token(self.api_key, self.secret_key)['Authorization'];
        return headers;

    def call(self, name, method, path, body='', headers={'Content-Type':'application/json'}):
        self.utils.debug_print(name)
        self.utils.debug_print(method)
        self.utils.debug_print(path)
        self.utils.debug_print(body)
        self.utils.debug_print(headers)

        browser = None
        try:
            if self.use_http:
                browser = http.client.HTTPConnection(self.url)
            else:
                if self.unverified_context:
                    browser = http.client.HTTPSConnection(self.url, context=ssl._create_unverified_context())
                else:
                    browser = http.client.HTTPSConnection(self.url)

            browser.request(method, path, body, self.append_auth_token_to_headers(headers))
            res = browser.getresponse()
            # read() must be called before close(), otherwise it will return an empty string
            data = res.read()

            if res.status >= 400:
                raise http.client.HTTPException(str(res.status) + ' ' + res.reason + (': ' + data.decode(encoding='UTF-8').strip() if data.decode(encoding='UTF-8').strip() else ''))

            # close() must be called after each request, or subsequent requests will be denied
            browser.close()
            #return data
            if data != '':
                try:
                    return (res.status, json.loads(data.decode(encoding='UTF-8')))
                except ValueError: # issues decoding the response
                    return (res.status, data.decode(encoding='UTF-8'))
            else:
                # No Content is a legitimate response
                if str(res.status) == '204':
                    return {}
                raise Exception(str(res.status) + res.reason)
        except http.client.HTTPException as h:
            print('UpGuard API request failed [' + name + ']: ' + str(h))
        finally:
            if browser is not None:
                browser.close()

def create_arg_parser():
    parser = argparse.ArgumentParser(description='Interact with the UpGuard API')
    parser.add_argument('-api_key', help='The API key for the appliance')
    parser.add_argument('-secret_key', help='The secret key for the appliance')
    parser.add_argument('-url', help='The URL for the appliance, with no scheme specified')
    parser.add_argument('-use_http', action='store_true', help='During development, can be used to make requests of HTTP instead of HTTPS')
    parser.add_argument('-unverified_context', action='store_true', help='Skip certificate verification. Use only if your UpGuard appliance has a self-signed certificate')
    parser.add_argument('-debug_mode', action='store_true', help='Turns on debugging messages')
    parser.add_argument('-hostname', help='The name of the node to start the scan for')
    parser.add_argument('-interval', help='The interval between scans')
    return parser


def main():
    args = create_arg_parser().parse_args()

    utils = Utils(args.debug_mode)

    api = API(args.api_key, args.secret_key, args.url, utils, args.use_http, args.unverified_context)

    status, response = api.call('heartbeat', 'GET', '/heartbeat')

    if status != 200:
        print("Could not contact {0}. Status code: {1}".format(args.url, status))
        return ERR_NO_HEARTBEAT

    print("Connected to {0} successfully. Looking up node".format(args.url))

    status, response = api.call('lookup', 'GET', "/api/v2/nodes/lookup.json?name={0}".format(urllib.parse.quote(args.hostname)))

    if status != 200:
        print("Could not find node via lookup using {0}".format(args.hostname))
        return ERR_NODE_NOT_FOUND

    node_id = response['node_id']

    print("Node '{0}' found via lookup, checking if last successful scan was within 12 hours".format(node_id))

    status, response = api.call('last_scan_status', 'GET', "/api/v2/nodes/{0}/last_scan_status.json".format(node_id))

    if status != 200:
        print("Could not look up last scan status for node with ID {0}".format(node_id))
        return ERR_LAST_STATUS_NOT_FOUND

    last_scan_date = datetime.datetime.strptime(response['updated_at'].split('.')[0], '%Y-%m-%dT%H:%M:%S')

    if last_scan_date > (datetime.datetime.now() - datetime.timedelta(hours=int(args.interval))):
        print("Last successful scan less than {0} hours ago ({1}), exiting".format(args.interval, last_scan_date))
        return ERR_SUCCESS

    print("Last scan was more than {0} hours ago, attempting to create scan task".format(args.interval))

    status, response = api.call('start_scan', 'POST', "/api/v2/nodes/{0}/start_scan.json".format(node_id))

    if status != 200:
        print("Failed to start scan for node with ID $nodeId")
        return ERR_COULD_NOT_START_SCAN

    print("Started scan job for node with ID {0}".format(node_id))

main()
