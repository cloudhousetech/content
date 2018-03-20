#!/usr/bin/python3

import csv
import http.client
import urllib
import json
import argparse
import ssl
import datetime
   
class Utils:

    def __init__(self, debug_mode=False):
        self.debug_mode = debug_mode

    def debug_callout_block(self, *args):
        self.debug_print_separator()
        for arg in args:
            self.debug_print(arg)
        self.debug_print_separator()

    def debug_print_separator(self):
        self.debug_print('')
        self.debug_print('======================================================================================================')
        self.debug_print('')

    def pretty_object_string(self, obj):
        return json.dumps(obj, sort_keys=True, indent=4, separators=(',', ': '))

    def debug_print(self, obj):
        if self.debug_mode:
            print(obj)

    def pretty_print_object(self, obj):
        print(self.pretty_object_string(obj))

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

    def non_paged_call(self, name, method, path, body='', headers=None, options=None):
        keep_going = True
        total_results = []

        if options is None:
            options = {}

        if headers is None:
            headers = {'Content-Type':'application/json'}

        page = options['page'] if 'page' in options else 1
        per_page = options['per_page'] if 'per_page' in options else 20

        while(keep_going):
            paging_string = ('?' if '?' not in path else '&') + (options['page_parameter'] if 'page_parameter' in options else 'page') + '=' + str(page)
            paging_string += '&' + (options['per_page_parameter'] if 'per_page_parameter' in options else 'per_page') + '=' + str(per_page)
            status, results = self.call(name, method, path + paging_string, body, headers)

            if status < 300:
                page += 1
                if 'json' in options:
                    results = json.loads(results) if type(results) == str else results
                    result_count = len(results) if type(results) is not int else 0
                    if 'attribute_to_accumulate' in options:
                        result_count = len(results[options['attribute_to_accumulate']]) if type(results[options['attribute_to_accumulate']]) is not int else 0
                        total_results = total_results + results[options['attribute_to_accumulate']]
                    else:
                        total_results = total_results + results

                    if result_count < per_page:
                        keep_going = False
            else:
                keep_going = False

        return total_results

def create_arg_parser():
    parser = argparse.ArgumentParser(description='Interact with the UpGuard API')
    parser.add_argument('-api_key', help='The API key for the appliance')
    parser.add_argument('-secret_key', help='The secret key for the appliance')
    parser.add_argument('-url', help='The URL for the appliance, with no scheme specified')
    parser.add_argument('-dry_run', action='store_true', help='If specified, will display the results of executing the script, without commiting any changes')
    parser.add_argument('-use_http', action='store_true', help='During development, can be used to make requests of HTTP instead of HTTPS')
    parser.add_argument('-unverified_context', action='store_true', help='Skip certificate verification. Use only if your UpGuard appliance has a self-signed certificate')
    parser.add_argument('-debug_mode', action='store_true', help='Turns on debugging messages')
    parser.add_argument('-policy', help='The name of the policy to update')
    parser.add_argument('-date_from', help='The lower bound date for diffs to be retrieved from. Defaults to yesterday')
    parser.add_argument('-date_to', help='The upper bound date for diffs to be retrieved from. Defaults to now')
    return parser

def find_checks_in_policy(utils, policy_data, parent_obj):
    flat_check_array = []
    current_obj = policy_data
    utils.debug_print('Current object is a {0}'.format(str(type(current_obj))))
    if type(current_obj) is list:
        utils.debug_print('List encountered: Recursing')
        for obj in current_obj:
            utils.debug_print('Recursing for item in list')
            flat_check_array = flat_check_array + find_checks_in_policy(utils, obj, current_obj)
    elif type(current_obj) is dict:
        utils.debug_print('Dict encountered: Looking for checks')
        utils.debug_print('Keys: [{0}]'.format(', '.join(list(current_obj.keys()))))
        if 'ci_path' in current_obj:
            utils.debug_print('Found "{0}" check with path [{1}]'.format(current_obj['name'], current_obj['ci_path']))
            flat_check_array = flat_check_array + [current_obj]
        else:
            for key, value in current_obj.items():
                utils.debug_print('Recursing with key "{0}"'.format(key))
                flat_check_array = flat_check_array + find_checks_in_policy(utils, value, current_obj)

    return flat_check_array

# this works by virtue of the fact that check object gets passed in by reference, thus it ultimately
# stays in the policy object itself and simply be changed-in place
def update_check(utils, check, attribute, check_value_pairs):
    utils.debug_print('Updating attribute "{0}" at path [{1}]'.format(attribute, ','.join(check['ci_path'])))
    utils.debug_print('Possible new checks are are:\n{0}\n'.format('\n'.join(["{0} '{1}'".format(c['check'], c['expected']) for c in check_value_pairs])))
    # TODO: put the code you want to use to select the right policy check value here
    # this is just an example, so we'll just use the value off the top
    new_check_and_value = check_value_pairs[0]
    # there may be multiple checks per attribute, and as such the check property is an array
    check['checks'][attribute].append(new_check_and_value)
    check['check_type'] = 'other'

def main():
    args = create_arg_parser().parse_args()

    utils = Utils(args.debug_mode)

    api = API(args.api_key, args.secret_key, args.url, utils, args.use_http, args.unverified_context)

    date_from = (datetime.datetime.now() - datetime.timedelta(hours=24)).strftime('%Y-%m-%d')
    if args.date_from:
        date_from = args.date_from
    date_to = datetime.datetime.now().strftime('%Y-%m-%d')
    if args.date_to:
        date_to = args.date_to

    latest_date = None

    status, policy_id = api.call('get_policy_by_name', 'GET', '/api/v2/policies/lookup.json?short_description={0}'.format(urllib.parse.quote_plus(args.policy)))

    if status > 299 or policy_id is None:
        print('Error code received while retrieving policy with name "{0}": {1}'.format(args.policy, status))
        return 1

    policy_id = int(policy_id['policy_id'])

    status, policy = api.call('get_policy', 'GET', '/api/v2/policies/{0}.json'.format(policy_id))

    if status > 299 or policy is None:
        print('Error code received while retrieving policy with name "{0}" (ID {1}): {2}'.format(args.policy, policy_id, status))
        return 2

    utils.debug_callout_block('Old policy contents:', utils.pretty_object_string(policy['data']))

    flat_check_array = find_checks_in_policy(utils, policy['data'], None)

    utils.debug_callout_block('Flat check list:', utils.pretty_object_string(flat_check_array))

    policy_results = api.non_paged_call('get_policy_results_list', 'GET', '/api/v2/policies/{0}/results_list.json?date_from={1}&date_to={2}'.format(policy_id, date_from, date_to), options={ 'json': True })

    utils.debug_callout_block('Policy Results:', utils.pretty_object_string(policy_results))

    results_by_path = {}

    for result in policy_results:
        # skip passing results, as they're obviously fine
        if result['result'] == 'passed':
            continue

        # generate all the possible wildcard variations, for quicker matching
        possible_paths = []
        for i in range(0, len(result['path'])):
            new_path_stars_first = ''
            new_path_stars_last = ''
            for j in range(0, len(result['path'])):
                if i < j:
                    new_path_stars_first += '*,'
                    new_path_stars_last += result['path'][j] + ','
                else:
                    new_path_stars_first += result['path'][j] + ','
                    new_path_stars_last += '*,'

            # also do a version that just has a single star replaced in various spots
            possible_paths.append(','.join(['*' if i == x else y for x,y in enumerate(result['path'])]))
            possible_paths.append(new_path_stars_first[:-1])
            # don't include a path that's just stars
            if new_path_stars_last.replace('*', '').replace(',', '') != '':
                possible_paths.append(new_path_stars_last[:-1])
        
        # create hash of policy results by path and wildcard path, including possible values
        # loop over this hash for each policy check, update values accordingly
        # have a "choose new value" function to be overriden
        for path in possible_paths:
            if path not in results_by_path:
                results_by_path[path] = { result['actual']: { result['check']: True } }
            else:
                if result['actual'] not in results_by_path[path]:
                    results_by_path[path][result['actual']] = { result['check']: True }
                else:
                    results_by_path[path][result['actual']][result['check']] = True

    # can't JSONify this, as there may be nulls as keys
    utils.debug_callout_block(results_by_path)

    for check in flat_check_array:
        # loop through each actual attribute check on the CI check itself, as the results_by_path
        # includes the attribute check name as well
        for attribute_check in list(check['checks']):
            # empty out the check array first; all of the entries will be replaced eventually
            check['checks'][attribute_check] = []
            # map the possible values into check type + value pairs
            # if it's not in the results hash, then it has passed and we don't need to check it
            desired_path = ','.join(check['ci_path'] + [attribute_check])
            if desired_path not in results_by_path:
                utils.debug_print('Not including check at path [{0}] as there are no discrepencies in results\n'.format(','.join(check['ci_path'] + [attribute_check])))
                continue

            possible_checks_and_values = results_by_path[desired_path]
            check_value_pairs = []
            for k,v in possible_checks_and_values.items():
                for check_type in v.keys():
                    check_value_pairs.append({ 'expected': k, 'check': check_type if check_type is not None else 'equals' }) # 'present' checks have a 'check' value of null in the results; this is an API deficiency
            update_check(utils, check, attribute_check, check_value_pairs)

    utils.debug_callout_block('New policy contents:', utils.pretty_object_string(policy['data']))

    utils.debug_print('Uploading new version of policy...')

    # need to rearrange the policy to work with PUT API, as the format we get out is broken
    policy['name'] = args.policy
    status, result = api.call('put_policy', 'PUT', '/api/v2/policies/{0}.json'.format(policy_id), json.dumps({ 'policy': policy }))

main()