import httplib;
import urllib;
import ssl;
import json;

# Parameters and constants
api_key = 'api key here'
secret_key = 'secret key here'
url = 'appliance.url.here' # use only FQDN, leave out the 'https://' portion
fromEnv = 4 # Set an environment id to transfer from
toEnv =   3 # Set an environment id to transfer to

try:
    # browser = httplib.HTTPConnection(url)
    # -- For HTTPS connections
    context = ssl._create_unverified_context()
    browser = httplib.HTTPSConnection(url, context=context)
    get_headers = {"Authorization": 'Token token="' + api_key + secret_key + '"',
    "Accept": "application/json"}
    browser.request("GET", "/api/v2/nodes.json", '', get_headers)
    get_res = browser.getresponse()
    # read() must be called before close(), or it will return an empty string
    data = get_res.read()
    if get_res.status >= 400:
        raise httplib.HTTPException(str(get_res.status) + ' ' +
            get_res.reason + (': ' + data.strip() if data.strip() else ''))
    else:
        print str(get_res.status) + get_res.reason;

    if data != '':
        nodes = json.loads(data)
        for node in nodes:
            node_id = node['id']
            environment_id = node['environment_id']

            if environment_id == fromEnv:
                # Change the node's environment_id = toEnv
                output = {'node' : { 'environment_id' : toEnv }}
                body = json.dumps(output)
                # Begin http connection for API call
                # conn = httplib.HTTPConnection(url)
                # -- For HTTPS connections
                conn = httplib.HTTPSConnection(url, context=context)
                put_headers = {"Authorization": 'Token token="' + api_key + secret_key + '"',
                "Accept": "application/json", 'Content-Type':'application/json'}
                conn.request("PUT", "/api/v2/nodes/" + str(node_id) +".json",
                    body, put_headers)
                update_res = conn.getresponse()
                if update_res.status >= 400:
                    raise httplib.HTTPException(str(update_res.status) + ' ' +
                        update_res.reason + (': ' + data.strip() if data.strip() else ''))
                conn.close();
    # close() must be called after each request, or subsequent requests will fail
    browser.close()

except httplib.HTTPException as h:
    print h.message;
finally:
    browser.close()
