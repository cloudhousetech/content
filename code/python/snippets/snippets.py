import http.client
import urllib
import re
import ssl
import json
import time

jobStatus = {"Failure": -1, "Pending": 0, "Processing": 1, "Success": 2, "Failure": 3}

def getBrowser(target_url, insecure=False):
    url = target_url
    if 'http' in url:
        # URL needs to be a hostname, so remove 'https://'
        url = re.sub('https?:\/\/', '', url)
    browser = http.client.HTTPConnection(url)
    if insecure:
        context = ssl._create_unverified_context()
        browser = http.client.HTTPSConnection(url, context=context)
    return browser

def APICall(browser, token, method, endpoint, body='', params={}):
    """
    Make an API request and return the JSON data response.

    This function uses the built-in http.client library.
    """
    parameters = urllib.urlencode(params) or None
    headers = {
        "Authorization": "Token token=\"{}\"".format(token),
        "Accept": "application/json",
        "Content-Type": "application/json"}
    if parameters:
        endpoint = "{}?{}".format(endpoint, parameters)
    try:
        browser.request(method, endpoint, body, headers)
        response = browser.getresponse()
        data = response.read()

        if response.status == 301:
            raise http.client.HTTPException(
                "Returned {}, try running with `--insecure` argument".format(response.status))
        elif response.status >= 400:
            raise http.client.HTTPException(
                "{} {}\n{}".format(
                    str(response.status),
                    response.reason,
                    (data.strip() if data else 'No Data Returned')))
        return response.status, data
    except http.client.HTTPException as h:
        print(h.message)

def getNodes(browser, token, details=False, group=None):
    """
    Return a list of node objects (by the index endpoint).

    Passing details=True will get all information for each node.

    Alternatively provide a node group (ID or name) to only get those nodes.
    """
    nodes = []
    page = 1
    per_page = 100

    done = False
    while not done:
        status, data = APICall(browser, token, "GET", "/api/v2/nodes.json", params={"page": page, "per_page": per_page})
        new_nodes = json.loads(data)
        nodes += new_nodes
        page += 1
        done = True if len(new_nodes) < per_page else False

    if details:
        detailed_nodes = []
        for node in nodes:
            status, data = APICall(browser, token, "GET", "/api/v2/nodes/{}.json".format(node["id"]))
            detailed_nodes.append(json.loads(data))
        return detailed_nodes
    return nodes

def getNodeGroups(browser, token, details=False):
    """
    Return a list of node group objects (by the index endpoint).

    Passing details=True will get all information for each node group.
    """
    groups = []
    page = 1
    per_page = 100

    done = False
    while not done:
        status, data = APICall(browser, token, "GET", "/api/v2/node_groups.json", params={"page": page, "per_page": per_page})
        new_node_groups = json.loads(data)
        groups += new_node_groups
        page += 1
        done = True if len(new_node_groups) < per_page else False

    if details:
        detailed_groups = []
        for group in groups:
            status, data = APICall(browser, token, "GET", "/api/v2/node_groups/{}.json".format(group["id"]))
            detailed_group = json.loads(data)
            detailed_group["scan_options"] = json.loads(detailed_group["scan_options"])
            detailed_groups.append(detailed_group)
        return detailed_groups
    return groups

def getConnectionManagerGroups(browser, token):
    """
    Return a list of connection manager groups (by the index endpoint).
    """
    status, data = APICall(browser, token, "GET", "/api/v2/connection_manager_groups.json")
    groups = json.loads(data)
    return groups

def getNodesInCMGroups(browser, token):
    """
    Return a dictionary of connection manager groups and the nodes associated with them:

    * key: CM Group ID
    * value: List of nodes
    """
    nodes = getNodes(browser=browser, token=token, details=True)
    cm_groups = getConnectionManagerGroups(browser=browser, token=token)

    result = {}
    for group in cm_groups:
        result[group["id"]] = []
    for node in nodes:
        if node["connection_manager_group_id"]:
            result[node["connection_manager_group_id"]].append(node)
    return result

def getPolicies(browser, token, details=False):
    """
    Return a list of policies
    """
    policies = []
    page = 1
    per_page = 50

    done = False
    while not done:
        status, data = APICall(browser, token, "GET", "/api/v2/policies.json", params={"page": page, "per_page": per_page})
        new_policies = json.loads(data)
        policies += new_policies
        page += 1
        done = True if len(new_policies) < per_page else False

    if details:
        detailed_policies = []
        for policy in policies:
            status, data = APICall(browser, token, "GET", "/api/v2/policies/{}.json".format(policy["id"]))
            detailed_policies.append(json.loads(data))
        return detailed_policies
    return policies

def addPolicy(browser, token, name):
    """
    Create a new policy with the given name
    """
    status, data = APICall(browser, token, "POST", "/api/v2/policies.json", body=json.dumps({"policy": {"name": name}}))
    new_policy = json.loads(data)
    return new_policy

def addNode(browser, token, obj):
    """
    Create a new node from the given node object (a dictionary)
    """
    status, data = APICall(browser, token, "POST", "/api/v2/nodes.json", body=json.dumps({"node": obj}))
    return json.loads(data)

def addNodeGroup(browser, token, obj):
    """
    Create a new node group from the given node group object (a dictionary)
    """
    status, data = APICall(browser, token, "POST", "/api/v2/node_groups.json", body=json.dumps({"node_group": obj}))
    return json.loads(data)

def getEvents(browser, token, view, since=None):
    """
    Return a list of events using the provided view name

    Optionally provide a datetime.date object in `since` to only return events from a certain date
    """
    events = []
    page = 1
    per_page = 100

    done = False
    while not done:
        status, data = APICall(browser, token, "GET", "/api/v2/events.json", params={"page": page, "per_page": per_page, "view_name": view, "date_from": since.strftime('%Y-%m-%d')})
        new_events = json.loads(data)
        events += new_events
        page += 1
        done = True if len(new_events) < per_page else False
    return events

def scan(browser, token, node=None, group=None, environment=None, wait=False, label=""):
    """
    Scan a node, group, or environment. If `wait` is True, then this function will wait for the scan job to complete before returning.
    """
    job = {}
    found_obj = False
    if node:
        nodes = getNodes(browser, token)
        for n in nodes:
            if n["name"].lower() == node:
                found_obj = True
                status, data = APICall(browser, token, "POST", "/api/v2/nodes/{}/start_scan.json".format(n["id"]), params={"label": label})
                result = json.loads(data)
                job["id"] = result["job_id"]
    elif group:
        pass
    elif environment:
        pass
    else:
        raise AttributeError("One of node, group, or environment must be provided.")

    if found_obj:
        if "id" in job:
            job["status"] = 0
            while job["status"] in [jobStatus["Pending"], jobStatus["Processing"]]:
                time.sleep(5)
                job = getJob(browser, token, job["id"])
        else:
            raise AttributeError("Job ID was not found from the scan job.")
    else:
        raise AttributeError("Object (node, group, or environment) was not found to start the scan.")
    return job

def getJob(browser, token, id):
    status, data = APICall(browser, token, "GET", "/api/v2/jobs/{}.json".format(id))
    return json.loads(data)
