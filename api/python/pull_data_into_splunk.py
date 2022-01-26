#!/usr/bin/python

import httplib;
import urllib;
import json;
import argparse;
import time;
from datetime import datetime;
import os;
import sys;

# Define constants here
api_key = ''
secret_key = ''
url = ''
start_time = datetime.utcnow()
    
def auth_token():
    return {'Authorization': 'Token token="' + api_key + secret_key + '"'}
   
def append_auth_token_to_headers(headers):
    headers['Authorization'] = auth_token()['Authorization'];
    return headers;

def _api_call(name, method, path, body='', headers={}):
    browser = None
    try:
        # Change to HTTPConnection() if necessary
        browser = httplib.HTTPSConnection(url)
        browser.request(method, path, body, append_auth_token_to_headers(headers))
        res = browser.getresponse()
        # read() must be called before close(), otherwise it will return an empty string
        data = res.read()
        
        if res.status >= 400:
            raise httplib.HTTPException(str(res.status) + ' ' + res.reason + (': ' + data.strip() if data.strip() else ''))
        
        # close() must be called after each request, or subsequent requests will be denied
        browser.close()
        #return data
        if data != '':
            return json.loads(data)
        else:
            raise Exception(str(res.status) + res.reason)
    except httplib.HTTPException as h:
        raise Exception('UpGuard API request failed [' + name + ']: ' + h.message)
    finally:
        if browser is not None:
            browser.close()

def final_diff_report(id):
    report = _api_call('diff_reports', 'GET', '/api/v1/change_report.json?node_group_id=' + str(id))
    result = []
    for item in report['diff_items']:
        print('updated_at: ' + str(datetime.strptime(item['updated_at'], '%Y-%m-%d %H:%M:%S.%f')))
        print('start_time: ' + str(start_time))
        if datetime.strptime(item['updated_at'], '%Y-%m-%d %H:%M:%S.%f') > start_time:
            result.append(item)

    return result
    #return [item for item in report['diff_items'] if datetime.strptime(item['updated_at'], '%Y-%m-%d %H:%M:%S.%f') > start_time]

def start_node_group_scan(id):
    job_list = []
    node_group_nodes = _api_call('node_group_nodes', 'GET', '/api/v1/node_groups/' + str(id) + '/nodes.json')
    print(json.dumps(node_group_nodes, sort_keys=True, indent=4, separators=(',', ': ')))
    for node in node_group_nodes:
        job_list.append(_api_call('start_scan', 'POST', '/api/v1/nodes/' + str(node['id']) + '/start_scan.json')['job_id'])
    return job_list

def retrieve_vulns(reported):
    vuln_list = []
    page = 1
    while True:
      retrieved = _api_call('vulnerabilities', 'GET', '/api/v2/vulns.json?per_page=50&page=' + str(page) + '&reported=' + str(reported))
      vuln_list = vuln_list + retrieved
      page += 1
      if (retrieved == []):
        return vuln_list
        
def jobs_finished(job_ids):
    for job in job_ids:
        result = _api_call('show_job', 'GET', '/api/v1/jobs/' + str(job) + '.json')['status']
        if not (result == 2 or result == -1):
            return False
    return True

def lock_file(action):
    if action == 'lock':
        f = open('/tmp/pull_data_lock', 'w')
        f.write('locked')
        f.close()
    else:
        os.remove('/tmp/pull_data_lock')

if __name__ == '__main__':
    parser = argparse.ArgumentParser\
    (description='UpGuard script for adding data into Splunk, currently supported features:' \
    ' Manipulate node groups, retrieve vulnerabilities')
    parser.add_argument('-api_key', help='The API key for the appliance')
    parser.add_argument('-secret_key', help='The secret key for the appliance')
    parser.add_argument('-url', help='The URL for the appliance, with no scheme specified')
    parser.add_argument('-node_group_id', help='The id of the Node Group to scan and retrieve a diff report for')
    parser.add_argument('-vuln_reported_type', help='The vulnerabilities to be reported, one of: today, month, all.')
    parser.add_argument('-force', help='Manually override lockfile to re-run node group scan')

    args = parser.parse_args()
    # Define endpoints
    if args.api_key is not None:
      api_key = args.api_key
    if args.secret_key is not None:
      secret_key = args.secret_key
    if args.url is not None:
      url = args.url

    # Toggle between manipulating nodes in node groups vs retrieving vulns
    if args.node_group_id is None:
        print('Starting data pull, time: ' + str(start_time))
        print('Writing lock file')
        lock_file('lock')
        print('Started retrieving vulns for ' + str(args.vuln_reported_type))
        vulns = retrieve_vulns(args.vuln_reported_type)
        print(json.dumps(vulns, sort_keys=True, indent=4, separators=(',', ': ')))
        print('Removing lock')
        lock_file('unlock')
        exit()

    if os.path.isfile('/tmp/pull_data_lock'):
        print('/tmp/pull_data_lock still exists; Exiting...')
        if args.node_group_id is True:
            lock_file('unlock')
            print('/tmp/pull_data_lock is removed; Continuing...')
        else:
            exit()

    print('Starting data pull, time: ', str(start_time))
    print('Writing lock file')
    lock_file('lock')
    print('Kicking off scan job for node group with id: ' + args.node_group_id)
    job_id_list = start_node_group_scan(int(args.node_group_id))
    print('Started node group scan job')
    while jobs_finished(job_id_list) == False:
        print('Waiting for jobs to finish')
        time.sleep(5)
    print('Jobs finished')
    print('Printing diff report for node group with Id: ' + args.node_group_id)
    print(json.dumps(final_diff_report(int(args.node_group_id)), sort_keys=True, indent=4, separators=(',', ': ')))
    print('Removing lock')
    lock_file('unlock')
