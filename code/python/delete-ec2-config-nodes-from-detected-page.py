# Goes through all detected nodes and if we find a EC2 Config node, delete it

# Usage:
#    python delete-ec2-config-nodes-from-detected-page.py --api_key "UpGuard API Key" --sec_key "UpGuard Secret Key" --url "https://you.upguard.com" [--dryrun]
#    --api_key : your UpGuard API key
#    --sec_key : your UpGuard Secret key
#    --url     : the full URL to your UpGuard instance, for example "https://you.upguard.com"
#    --dryrun  : if specified, the script prints what it intends to do without actually doing it
#    --debug   : if specified, print out extra debug statements when running

import sys
import re
import httplib
import ssl
import urllib
import json

debug = False

def LogDebug(msg):
    if debug:
        print "DEBUG: " + str(msg)

def ThrowWebError(response):
    raise httplib.HTTPException("{}: {}: {}".format(str(response.status), str(response.reason), str(response.read())))

api_key = None
sec_key = None
url = None
insecure = False
dryrun = False

for i in range(1, len(sys.argv)):
    a = sys.argv[i]
    if a == "--api_key":
        api_key = sys.argv[i+1]
    if a == "--sec_key":
        sec_key = sys.argv[i+1]
    if a == "--url":
        url = sys.argv[i+1]
    if a == "--dryrun":
        dryrun = True
    if a == "--debug":
        debug = True
    if a == "-h" or a == "--help":
        print "Read the comments at the top of the python script"
        exit

if api_key == None or api_key == '':
    raise Exception("Missing --api_key param")
if sec_key == None or sec_key == '':
    raise Exception("Missing --sec_key param")
if url == None or url == '':
    raise Exception("Missing --url param")

url = re.sub('https?:\/\/', '', url)

def makeHeaders():
    return {
        "Authorization": "Token token=\"{}{}\"".format(api_key, sec_key),
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded"
    }

def makeBrowser():
    browser = httplib.HTTPSConnection(url)
    if insecure:
        context = ssl._create_unverified_context()
        browser = httplib.HTTPSConnection(url, "443", context)
    return browser

def GetAllDetectedNodes():
    params = urllib.urlencode({"page": 1, "per_page": 5000, "status": "detected"})
    browser = makeBrowser()
    browser.request("GET", "/api/v2/nodes.json", params, makeHeaders())
    response = browser.getresponse()
    if response.status >= 400:
        ThrowWebError(response)
    return json.loads(response.read())

def DeleteNode(node_id):
    browser = makeBrowser()
    browser.request("DELETE", "/api/v2/nodes/" + str(node_id) + ".json", None, makeHeaders())
    response = browser.getresponse()
    if response.status >= 400:
        ThrowWebError(response)
    return

LogDebug("About to ask for a list of all detected nodes")

nodes = GetAllDetectedNodes()

for node in nodes:
    print "Checking node '" + str(node["name"]) + "'"
    if node["operating_system_id"] == 2801:
        LogDebug("Node is EC2 config node type")
        if dryrun:
            print "Would have deleted this node, but we're dryrun-ing"
        else:
            DeleteNode(node["id"])
            print "Deleted"
    else:
        LogDebug("Skipping node, not EC2 config type")
print "DONE"
