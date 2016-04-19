#!/usr/bin/python

import csv
import httplib;
import urllib;
import json;
import argparse;
   
class API:
    def __init__(self, api_key, secret_key, url, use_ssl=True):
        self.api_key = api_key
        self.secret_key = secret_key
        self.url = url
        self.use_ssl = use_ssl

    def auth_token(self, api_key, secret_key):
        return {'Authorization': 'Token token="' + api_key + secret_key + '"'}
       
    def append_auth_token_to_headers(self, headers):
        headers['Authorization'] = self.auth_token(self.api_key, self.secret_key)['Authorization'];
        return headers;
            
    def call(self, name, method, path, body='', headers={}):
        browser = None
        try:
            if self.use_ssl:
                browser = httplib.HTTPSConnection(self.url)
            else:
                browser = httplib.HTTPConnection(self.url)

            browser.request(method, path, body, self.append_auth_token_to_headers(headers))
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
                # No Content is a legitimate response
                if str(res.status) == '204':
                    return {}
                raise Exception(str(res.status) + res.reason)
        except httplib.HTTPException as h:
            raise Exception('ScriptRock API request failed [' + name + ']: ' + str(h))
        finally:
            if browser is not None:
                browser.close()

def create_arg_parser():
    parser = argparse.ArgumentParser(description='Manipulate node groups')
    parser.add_argument('-api_key', help='The API key for the appliance')
    parser.add_argument('-secret_key', help='The secret key for the appliance')
    parser.add_argument('-url', help='The URL for the appliance, with no scheme specified')
    parser.add_argument('-node_group_id', help='The ndoe group that the CSV file defines membership for')
    parser.add_argument('-csv_path', help='The path to the CSV file to import from')
    parser.add_argument('-headers', help='The list of column headers (comma separated) for the CSV file. The order must match that of the CSV file')
    parser.add_argument('-filters', help='A list of columns to filter by, in the format "filter_column_name=option[|option]"')
    parser.add_argument('-dry_run', action='store_true', help='If specified, will display the results of executing the script, without commiting any changes')
    parser.add_argument('-name_column', default='name', help='The column that contains node names. Defaults to "name"')
    parser.add_argument('-no_ssl', action='store_true', help='During development, can be used to make requests of HTTP instead of HTTPS')
    return parser

def get_node_list(csv_path, name_column, raw_filters, dry_run, headers=None):
    final_node_list = []
    name_column_index = 0
    skipped_rows = 0

    with open(csv_path, 'rb') as f:
        reader = csv.reader(f)
        node = {}
        

        filters = {}
        for kvp in raw_filters.split(';'):
            if kvp == '':
                continue
            k, v = kvp.split('=')
            filters[k] = v.split('|') # results in an array, regardless as to whether or not a split actually occured

        for row in reader:
            node_acceptable = True
            reason_string = ''
            
            if headers == None:
                # if no headers are specified on the command line, use the first row as the headers
                headers = row

                if name_column not in headers:
                    print('Column "' + str(name_column) + '" was not found in the headers')
                    return []

                name_column_index = headers.index(name_column)
                continue

            # we can't do anything if there is no node name, but don't want to print out an entry for every blank line, so just keep a count
            if not str(row[name_column_index]):
                skipped_rows = skipped_rows + 1
                continue

            for index, header in enumerate(headers):
                if header in filters:
                    if node_acceptable == False:
                        break;

                    reason_string += header + ' = ' + row[index] + '; '
                    if row[index] not in filters[header]:
                        node_acceptable = False
                        
            if node_acceptable:
                print('Adding node ' + row[name_column_index] + ' to group because it matched filters ' + reason_string)
                final_node_list.append(row[name_column_index])
            else:
                print('Not adding node ' + row[name_column_index] + ' to group because it did not match filters ' + reason_string)

    if skipped_rows > 0:
        print(str(skipped_rows) + ' rows were skipped because the name column was blank')

    return final_node_list

def change_group_membership(node_list, target_group, api, dry_run):
    existing_node_ids_in_group = [node['id'] for node in api.call('get_node_group_nodes', 'GET', '/api/v1/node_groups/' + str(target_group) + '/nodes.json')]
    new_member_ids = []

    for node in node_list:
            retrieved_node = None
            try:
                retrieved_node = api.call('get_node', 'GET', '/api/v1/nodes/lookup.json?name=' + str(node))
            except Exception as e:
                print('Could not retrieve node ' + node)
                print(e)
                continue

            # in case we get some wierd respone back
            # 'lookup' just returns the Id in an object like so: { "node_id": 1 }
            if 'node_id' not in retrieved_node:
                print('Could not retrieve node ' + node + ': Id was not found on the returned object')
                continue
            else:
                new_member_ids.append(retrieved_node['node_id'])

    remove_ids = [n for n in existing_node_ids_in_group if n not in new_member_ids]
    
    for r_id in remove_ids:
        if dry_run:
            print('Removing node with ID ' + str(r_id) + ' from node group with ID ' + str(target_group))
            continue

        api.call('remove_node_from_group', 'POST', '/api/v1/node_groups/' + str(target_group) + '/remove_node.json?node_id=' + str(r_id))

    add_ids = [n for n in new_member_ids if n not in existing_node_ids_in_group]

    for a_id in add_ids:
        if dry_run:
            print('Adding node with ID ' + str(a_id) + ' to node group with ID ' + str(target_group))
            continue

        api.call('add_node_to_group', 'POST', '/api/v1/node_groups/' + str(target_group) + '/add_node.json?node_id=' + str(a_id))

def main():
    args = create_arg_parser().parse_args()

    api = API(args.api_key, args.secret_key, args.url, not args.no_ssl)

    change_group_membership(get_node_list(args.csv_path, args.name_column, args.filters, args.dry_run, args.headers), args.node_group_id, api, args.dry_run)

main()









