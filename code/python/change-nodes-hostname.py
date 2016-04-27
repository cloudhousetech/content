import httplib;
import urllib;
import json;
import ssl;

api_key = '<< api key >>'
secret_key = '<< secret key >>'
url = 'your.appliance.url' # No scheme needed
domainName = '.domain.com' # Domain to append to the hostname
userName = 'accountName' # SSH Username

try:
    browser = httplib.HTTPConnection(url)
    context = ssl._create_unverified_context()
    browser = httplib.HTTPSConnection(url, context=context)
    get_headers = {"Authorization": 'Token token="' + api_key + secret_key + '"',
    "Accept": "application/json"}
    browser.request("GET", "/api/v2/nodes.json?page=1&per_page=500", '', get_headers)
    get_res = browser.getresponse()
    nodeList = get_res.read()
    browser.close()

    if get_res.status >= 400:
        raise httplib.HTTPException(str(get_res.status) + ' ' +
            get_res.reason + (': ' + nodeList.strip() if nodeList.strip() else ''))

    if nodeList != '':
        nodeListJson = json.loads(nodeList)
        count = 1
        for node in nodeListJson:
            node_id = node['id']

            browser.request("GET", "/api/v2/nodes/" + str(node_id), '', get_headers)
            get_res = browser.getresponse()
            nodeDetail = get_res.read()
            browser.close()

            if get_res.status >= 400:
                    raise httplib.HTTPException(str(get_res.status) + ' ' +
                        get_res.reason + (': ' + nodeDetail.strip() if nodeDetail.strip() else ''))

            if nodeDetail != '':
                nodeDetailJson = json.loads(nodeDetail)
                print "Updating " + nodeDetailJson['name'] + " (" + str(count) + "/" + str(len(nodeListJson)) + ")"

                medium_hostname = nodeDetailJson['name'] + domainName
                medium_username = userName

                output = {'node' : { 'medium_hostname' : medium_hostname, 'medium_username' : medium_username }}
                body = json.dumps(output)

                put_headers = {"Authorization": 'Token token="' + api_key + secret_key + '"',
                "Accept": "application/json", 'Content-Type':'application/json'}
                browser.request("PUT", "/api/v2/nodes/" + str(node_id) +".json", body, put_headers)
                update_res = browser.getresponse()
                browser.close();

                if update_res.status >= 400:
                    raise httplib.HTTPException(str(update_res.status) + ' ' +
                        update_res.reason + (': ' + data.strip() if data.strip() else ''))

            count = count + 1

except httplib.HTTPException as h:
    print h.message;
finally:
    browser.close()
