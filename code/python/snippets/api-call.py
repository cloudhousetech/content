"""
Make an API call to an endpoint.

To use:

After copying the snippet to the top of your script, you can use it as:

```
try:
    browser = setupBrowser()
    status, data = APICall(browser, "GET", "/api/v2/nodes.json")
except httplib.HTTPException as h:
    print h.message;
finally:
    if browser:
        browser.close()
```

Note: This uses arguments provided by `arguments.py`
"""

import httplib
import re
import ssl

def setupBrowser():
    url = args.target_url
    if 'http' in url:
        # URL needs to be a hostname, so remove 'https://'
        url = re.sub('https?:\/\/', '', url)
    browser = httplib.HTTPConnection(url)
    if args.insecure:
        context = ssl._create_unverified_context()
        browser = httplib.HTTPSConnection(url, context=context)
    return browser

def APICall(browser, method, endpoint, body='', page=1, per_page=100):
    try:
        browser.request(method, endpoint, body,
            {"Authorization": "Token token=\"{}{}\"".format(args.api_key, args.secret_key)),
            "Accept": "application/json"})
        response = browser.getresponse()
        data = response.read()

        if response.status == 301:
            raise httplib.HTTPException(
                "Returned {}, try running with `--insecure` argument".format(response.status))
        elif response.status >= 400:
            raise httplib.HTTPException(
                "{} {}\n{}".format(
                    str(response.status),
                    response.reason,
                    (data.strip() if data else 'No Data Returned')))
    except httplib.HTTPException as h:
        print h.message
    return response.status, data
