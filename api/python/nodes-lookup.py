import httplib;
import urllib;
import json;

api_key = 'api key here'
secret_key = 'secret key here'
url = 'appliance.url.here'

try:
    browser = httplib.HTTPConnection('localhost:3000')

    browser.request("POST",
        "/api/v1/nodes/42/add_to_node_group.json?node_group_id=23",
        '',
        {"Authorization": 'Token token="' + api_key + secret_key + '"',
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded"})
    res = browser.getresponse()
    # read() must be called before close(), or it will return an empty string
    data = res.read()

    if res.status >= 400:
        raise httplib.HTTPException(str(res.status) + ' ' +
            res.reason + (': ' + data.strip() if data.strip() else ''))

    # close() must be called after each request, or subsequent requests will fail
    browser.close()

    if data != '':
        return json.dumps(json.loads(data), sort_keys=True,
            indent=4, separators=(',', ': '))
    else:
        return str(res.status) + res.reason;
except httplib.HTTPException as h:
    return h.message;
finally:
    browser.close()