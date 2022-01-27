# For all AWS EC2 nodes in UpGuard, if we can't seem to find that node's
# existence in AWS, move the node to a holding node group for final
# review before deletion.

# For AWS checking, please install 'boto3'
# > pip install boto3

# Usage:
#    python move-extinct-aws-nodes.py --api_key "UpGuard API Key" --sec_key "UpGuard Secret key" --url "https://you.upguard.com" --dest_node_group_id 123
#    --api_key                 : your UpGuard API key
#    --sec_key                 : your UpGuard API secret key
#    --url                     : the full URL of your UpGuard instance, for example 'https://you.upguard.com'
#    --dest_node_group_id      : the ID of the node group you want to move extinct nodes to for final review and possible delete
#    --ignore_node_name_prefix : if specified, nodes with names matching this prefix will be ignored and not moved to the dest node group
#    --insecure                : if you are using a self signed or not-prefect SSL cert, this prevents SSL cert checks connecting to your appliance
#    --dryrun                  : if specified, the script prints out what it would like to do rather than actually moving any nodes
#    --debug                   : if specified, print out extra debug statements when running

import sys
import re
import boto3
import botocore
import httplib
import ssl
import urllib
import json

debug = False

def TODO():
    raise Exception("NotImplemented")

def LogWarning(msg):
    print "WARN: " + str(msg)

def LogDebug(msg):
    if debug:
        print "DEBUG: " + str(msg)

def ThrowWebError(response):
    raise httplib.HTTPException("{}: {}".format(str(response.status), str(response.reason)))

api_key = None
api_sec = None
url = None
dest_node_group_id = None
ignore_node_name_prefix = None
insecure = False
dryrun = False

for i in range(1, len(sys.argv)):
    a = sys.argv[i]
    if a == "--api_key":
        api_key = sys.argv[i+1]
    if a == "--sec_key":
        api_sec = sys.argv[i+1]
    if a == "--url":
        url = sys.argv[i+1]
    if a == "--dest_node_group_id":
        dest_node_group_id = sys.argv[i+1]
    if a == "--insecure":
        insecure = True
    if a == "--dryrun":
        dryrun = True
    if a == "--debug":
        debug = True
    if a == "-h" or a == "--help":
        print "Read the comments at the top of the python script"
        exit

if api_key == None or api_key == '':
    raise Exception("Missing --api_key param")
if api_sec == None or api_sec == '':
    raise Exception("Missing --api_sec param")
if url == None or url == '':
    raise Exception("Missing --url param")
if dest_node_group_id == None or dest_node_group_id == '':
    if dryrun == False:
        raise Exception("Missing --dest_node_group_id param")

url = re.sub('https?:\/\/', '', url)
    
def ShouldIgnoreNodeDueToPrefix(node_name):
    if ignore_node_name_prefix == None or ignore_node_name_prefix == '':
        return False
    else:
        if node_name.startsWith(ignore_node_name_prefix):
            return True
        else:
            return False

def makeHeaders():
    return {
        "Authorization": "Token token=\"{}{}\"".format(api_key, api_sec),
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded"
    }

def makeBrowser():
    browser = httplib.HTTPSConnection(url)
    if insecure:
        context = ssl._create_unverified_context()
        browser = httplib.HTTPSConnection(url, "443", context)
    return browser

def GetNodeObject(node_id):
    browser = makeBrowser()
    browser.request("GET", "/api/v2/nodes/" + str(node_id) + ".json", '', makeHeaders())
    response = browser.getresponse()
    if response.status >= 400:
        ThrowWebError(response)
    return json.loads(response.read())

def GetMostRecentNodeScanForNode(node_id):
    browser = makeBrowser()
    browser.request("GET", "/api/v2/nodes/" + str(node_id) + "/scan_details.json", '', makeHeaders())
    response = browser.getresponse()
    if response.status == 404:
        return None
    
    if response.status >= 400:
        ThrowWebError(response)
    return json.loads(response.read())

def HasProp(obj, prop):
    if prop in obj.keys():
        return True
    else:
        return False

def IsNodeEC2NodeType(node_id):
    LogDebug("IsNodeEC2NodeType(" + str(node_id) + ")")

    node = GetNodeObject(node_id)
    if str(node['operating_system_id']) == "2801":
        return { "is": True, "instance_id": node['external_id'], "region": "us-east-1" }

    x = re.search("^(i-[0-9a-fA-F]+)$", str(node["external_id"]))
    if x != None:
        return { "is": True, "instance_id": x.group(), "region": "us-east-1" }
    
    latest_node_scan = GetMostRecentNodeScanForNode(node_id)
    if latest_node_scan == None:
        LogWarning("node " + str(node['name']) + " [id=" + str(node_id) + "] doesn't seem to have a latest scan, so can't check if its EC2")
        return { "is": False, "instance_id": "", "region": "" }

    latest_node_scan_data_lower = latest_node_scan['data'].lower()
    
    if "services" in latest_node_scan_data_lower:
        if "windows" in latest_node_scan_data_lower:
            if "ec2config" in latest_node_scan_data_lower:
                return { "is": True, "instance_id": node['external_id'], "region": "us-east-1" }

    if "envvars" in latest_node_scan_data_lower:
        if "linux" in latest_node_scan_data_lower:
            if "ec2_home" in latest_node_scan_data_lower:
                return { "is": True, "instance_id": node['external_id'], "region": "us-east-1" }

    # doesn't match any of our heuristics, so probably not EC2 instance
    return { "is": False, "instance_id": "", "region": "" }

def CheckIfInstanceExists(instance_id, region):
    LogDebug("About to check if we can find an EC2 instance with ID " + str(instance_id))

    try:
        ec2 = boto3.client('ec2', region_name=region)
        response = ec2.describe_instances(InstanceIds=[instance_id])
        if 'Reservations' in response:
            if len(response['Reservations']) == 0:
                return False
            elif len(response['Reservations']) == 1:
                return True
            else:
                raise Exception("Got back more than one instance record when looking up instance " + str(instance_id))
        raise Exception("not the layout of response I was expectig")
    except botocore.exceptions.NoRegionError:
        raise Exception("Region not specified")
    except botocore.exceptions.NoCredentialsError:
        raise Exception("You've forgotten to specify your credentials. See https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html")
    except botocore.exceptions.ClientError, ex:
        if "InvalidInstanceID.NotFound" in str(ex):
            return False
        elif "InvalidInstanceID.Malformed" in str(ex):
            return None  # code for "please skip this one"
        else:
            raise ex
    except Exception, ex:
        raise ex
    
def MoveNodeIntoNodeGroup(node_id, node_group_id):
    params = urllib.urlencode({"node_group_id": node_group_id})
    browser = makeBrowser()
    browser.request("POST", "/api/v2/nodes/" + str(node_id) + "/add_to_node_group.json", params, makeHeaders())
    response = browser.getresponse()
    if response.status >= 400:
        ThrowWebError(response)
    return json.loads(response.read())

def GetAllNodes():
    params = urllib.urlencode({ "page": 1, "per_page": 50000 })
    browser = makeBrowser()
    browser.request("GET", "/api/v2/nodes.json", params, makeHeaders())
    response = browser.getresponse()
    if response.status >= 400:
        ThrowWebError(response)
    return json.loads(response.read())

LogDebug("About to ask for a list of all nodes")

nodes = GetAllNodes()

for node in nodes:
    print "Checking node '" + str(node['name']) + "'"
    LogDebug("About to get more information no node " + node['name'] + " [id=" + str(node['id']) + "]")
    node_details = GetNodeObject(node['id'])

    if ShouldIgnoreNodeDueToPrefix(node_details['name']):
        print "Skipping " + str(node_details['name']) + " [id=" + str(node_details['id']) + "] because it matches the ignore_node_name_prefix prefix"
        continue

    isEC2 = IsNodeEC2NodeType(node['id'])
    if isEC2['is'] == False:
        print "Skipping " + str(node_details['name']) + " [id=" + str(node_details['id']) + "] because it isn't EC2 enough"
        continue

    if isEC2['is'] == True:
        instance_id = isEC2['instance_id']
        region = isEC2['region']

        if instance_id == '':
            LogWarning("I think " + str(node_details['name']) + " [id=" + str(node_details['id']) + "] is EC2, but the node record doesn't have an instance ID stored in the node.external_id field")
            continue

        exists = CheckIfInstanceExists(instance_id, region)
        if exists == None:
            print "I've been told to skip over checking AWS for this node because something isn't quite right"
            print "  - node.id          = " + str(node['id'])
            print "  - node.name        = " + str(node_details['name'])
            print "  - node.external_id = " + str(node_details['external_id'])
            continue
        if exists:
            print "Instance exists in AWS, leaving as is"
            continue

        LogDebug("Couldn't find node as instance in AWS")
        if dryrun:
            print "DRYRUN: Would have tried to add node " + str(node_details['name']) + " [external_id=" + str(node_details['external_id']) + "] to the node group specified with --dest_node_group_id"
        else:
            print "Moving node to dest_node_group_id"
            MoveNodeIntoNodeGroup(node['id'], dest_node_group_id)

LogDebug("DONE")
        
