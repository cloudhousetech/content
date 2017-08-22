import csv
import httplib;
import urllib;
import json;
import argparse;

api_key = 'YOUR API KEY HERE'
secret_key = 'YOUR SECRET KEY HERE'
url = 'your.url.here'

def get_file_id(node, file_path):
    browser = httplib.HTTPConnection(url)
    try:
        browser.request('GET', '/api/v2/nodes/' + str(node) + '/ci_data?ci_type=files', '', 
            {'Authorization': 'Token token="' + api_key + secret_key + '"',
            'Accept':'application/json'})
        res = browser.getresponse()

        data = res.read()
    
        if res.status >= 400:
            print str(res.status) + ' ' + res.reason
            raise httplib.HTTPException(str(res.status) + ' ' + res.reason + (': ' + data.strip() if data.strip() else ''))
    

        browser.close()

        if data != '':
            for t, tval in json.loads(data).iteritems():
                for f, fval in tval.iteritems():
                    if f == file_path and 'text_file_id' in fval:
                        return fval['text_file_id']

            return None
        else:
            return str(res.status) + res.reason;
    except httplib.HTTPException as h:
        return h.message;
    finally:
        browser.close()

def get_file(text_file_id):
    browser = httplib.HTTPConnection(url)
    try:
        browser.request('GET', '/api/v2/text_files/' + str(text_file_id), '', 
            {'Authorization': 'Token token="' + api_key + secret_key + '"',
            'Accept':'application/json'})
        res = browser.getresponse()

        data = res.read()
    
        if res.status >= 400:
            print str(res.status) + ' ' + res.reason
            raise httplib.HTTPException(str(res.status) + ' ' + res.reason + (': ' + data.strip() if data.strip() else ''))
    

        browser.close()

        if data != '':
            return json.loads(data)['data']
        else:
            return str(res.status) + res.reason;
    except httplib.HTTPException as h:
        return h.message;
    finally:
        browser.close()
   
parser = argparse.ArgumentParser(description='Retrieve a file associated with a node.')
parser.add_argument('node_id', help='The ID of the node the file is associated with.')
parser.add_argument('file_path', help='The file path as it is stored in ScriptRock.')

args = parser.parse_args()

file_id = get_file_id(int(args.node_id), args.file_path)    
if file_id is not None: 
    print(get_file(file_id))
else:
    print("Requested file not associated with specified node")
