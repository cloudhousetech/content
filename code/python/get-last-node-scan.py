import httplib;
import urllib;
import json;
import sys;

def recurse_to_key(obj, key):
    if isinstance(obj, dict):
        for k, value in obj.iteritems():
            if k == key:
                return obj[k]
            else:
                data = recurse_to_key(value, key)
                    if data != None:
                        try:
                            if isinstance(data, unicode):
                                return json.loads(unicodedata.normalize('NFKD', data).encode('ascii','ignore'))
                            else:
                                return json.loads(data)
                        except:
                            return data
    elif isinstance(obj, list):
        for avalue in obj:
            data = recurse_to_key(avalue, key)
            if data != None:
                try:
                    if isinstance(data, unicode):
                        return json.loads(unicodedata.normalize('NFKD', data).encode('ascii','ignore'))
                    else:
                        return json.loads(data)
                except:
                    return data
            else:
                try:
                    parsed = json.loads(obj)
                    sdata = recurse_to_key(parsed, key)
                    if sdata != None:
                        try:
                            if isinstance(sdata, unicode):
                                return json.loads(unicodedata.normalize('NFKD', sdata).encode('ascii','ignore'))
                            else:
                                return json.loads(sdata)
                        except:
                            return sdata
                except:
                    pass

    return None

def get_key_info(json_string, key):
    parsed = json.loads(json_string)
    return recurse_to_key(parsed, key)

hostname = "your.appliance.address"
api_key = "11111"
secret_key = "222222"

try:
    browser = httplib.HTTPConnection(hostname)

    browser.request("GET", "/api/v2/nodes/1/last_node_scan_details?with_data=true", '',
 {"Authorization": "Token token=\"" + api_key + secret_key + "\"",
 "Accept": "application/json"})
    res = browser.getresponse()
    data = res.read()

    if res.status >= 400:
        raise httplib.HTTPException(str(res.status) + ' ' +
 res.reason + (': ' + data.strip() if data.strip() else ''))

    browser.close()

    if data != '':
        print(json.dumps(get_key_info(data, "Sublime Text")['version'], indent=4))
    else:
        print str(res.status) + res.reason;
except httplib.HTTPException as h:
    print h.message;
finally:
    browser.close()
