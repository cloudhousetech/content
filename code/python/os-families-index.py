    import httplib;
    import json;

    try:
        browser = httplib.HTTPConnection('localhost:3000')
        browser.request("GET", "/api/v1/operating_system_families.json", '',
            {"Authorization": "Token token="AB123456CDEF7890GH",
            "Accept": "application/json"})
        res = browser.getresponse()
        # read() must be called before close(), or it will return an empty string
        data = res.read()

        if res.status >= 400:
            raise httplib.HTTPException(str(res.status) + ' ' +
                res.reason + (': ' + data.strip() if data.strip() else ''))

        # close() must be called after each request, or subsequent requests will fail
        browser.close()

        if data != '':
            print json.dumps(json.loads(data), sort_keys=True,
                indent=4, separators=(',', ': '))
        else:
            print str(res.status) + res.reason;
    except httplib.HTTPException as h:
        print h.message;
    finally:
        browser.close()
