import requests
import re
import ssl
import json
import time

jobStatus = {"Failure": -1, "Pending": 0, "Processing": 1, "Success": 2, "Failure": 3}

def getUrl(url):
    """
    Return a URL from a hostname
    """
    if "https" in url: return url
    if "http" in url:
        # Remove http and add https
        return "https://{}".format(re.sub('http?:\/\/', '', url))
    return "https://{}".format(url)

def getSession(api_key, secret_key, insecure=False):
    session = requests.Session()
    session.headers.update({"Authorization": "Token token=\"{}{}\"".format(api_key, secret_key)})
    session.headers.update({"Content-Type": "application/json"})
    if insecure:
        requests.packages.urllib3.disable_warnings()
    return session

def getNodes(session, url, details=False, group=None):
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
        new_nodes = session.get("{}/api/v2/nodes.json".format(url), params={"page": page, "per_page": per_page}).json()
        nodes += new_nodes
        page += 1
        done = True if len(new_nodes) < per_page else False

    if details:
        detailed_nodes = []
        for node in nodes:
            detailed_nodes.append(session.get("{}/api/v2/nodes/{}.json".format(url, node["id"])).json())
        return detailed_nodes
    return nodes

def getNodeGroups(session, url, details=False):
    """
    Return a list of node group objects (by the index endpoint).

    Passing details=True will get all information for each node group.
    """
    groups = []
    page = 1
    per_page = 100

    done = False
    while not done:
        new_node_groups = session.get("{}/api/v2/node_groups.json".format(url), params={"page": page, "per_page": per_page}).json()
        groups += new_node_groups
        page += 1
        done = True if len(new_node_groups) < per_page else False

    if details:
        detailed_groups = []
        for group in groups:
            detailed_group = session.get("{}/api/v2/node_groups/{}.json".format(url, group["id"])).json()
            detailed_group["scan_options"] = json.loads(detailed_group["scan_options"])
            detailed_groups.append(detailed_group)
        return detailed_groups
    return groups

def getConnectionManagerGroups(session, url):
    """
    Return a list of connection manager groups (by the index endpoint).
    """
    groups = []
    page = 1
    per_page = 100

    done = False
    while not done:
        new_cm_groups = session.get("{}/api/v2/connection_manager_groups.json".format(url), params={"page": page, "per_page": per_page}).json()
        groups += new_cm_groups
        page += 1
        done = True if len(new_cm_groups) < per_page else False
    return groups

def getNodesInCMGroups(session, url):
    """
    Return a dictionary of connection manager groups and the nodes associated with them:

    * key: CM Group ID
    * value: List of nodes
    """
    nodes = getNodes(session=session, url=url, details=True)
    cm_groups = getConnectionManagerGroups(session=session, url=url)

    result = {}
    for group in cm_groups:
        result[group["id"]] = []
    for node in nodes:
        if node["connection_manager_group_id"]:
            result[node["connection_manager_group_id"]].append(node)
    return result

def getPolicies(session, url, details=False):
    """
    Return a list of policies
    """
    policies = []
    page = 1
    per_page = 50

    done = False
    while not done:
        new_policies = session.get("{}/api/v2/node_groups.json".format(url), params={"page": page, "per_page": per_page}).json()
        policies += new_policies
        page += 1
        done = True if len(new_policies) < per_page else False

    if details:
        detailed_policies = []
        for policy in policies:
            detailed_policies.append(session.get("{}/api/v2/policies/{}.json".format(url, policy["id"])).json())
        return detailed_policies
    return policies

def addPolicy(browser, token, name):
    """
    Create a new policy with the given name
    """
    raise NotImplementedError
    status, data = APICall(browser, token, "POST", "/api/v2/policies.json", body=json.dumps({"policy": {"name": name}}))
    new_policy = json.loads(data)
    return new_policy

def addNode(session, url, node, verify=True):
    """
    Create a new node from the given node object (a dictionary)
    """
    response = session.post("{}/api/v2/nodes.json".format(url), params={}, data=json.dumps({"node": node}), verify=verify).json()
    return response

def addNodeGroup(browser, token, obj):
    """
    Create a new node group from the given node group object (a dictionary)
    """
    raise NotImplementedError
    status, data = APICall(browser, token, "POST", "/api/v2/node_groups.json", body=json.dumps({"node_group": obj}))
    return json.loads(data)

def getEvents(session, url, view, since=None):
    """
    Return a list of events using the provided view name

    Optionally provide a datetime.date object in `since` to only return events from a certain date
    """
    events = []
    page = 1
    per_page = 100

    done = False
    while not done:
        new_events = session.get("{}/api/v2/events.json".format(url), params={"page": page, "per_page": per_page, "view_name": view, "date_from": since.strftime('%Y-%m-%d')}).json()
        events += new_events
        page += 1
        done = True if len(new_events) < per_page else False
    return events

def scan(session, url, node=None, group=None, environment=None, wait=False, label=""):
    """
    Scan a node, group, or environment by name. The ID for the object (node, group, or environment) will be found automatically.

    If `wait` is True, then this function will wait for the scan job to complete before returning.
    """
    job = {}
    found_obj = False
    if node:
        nodes = getNodes(session, url)
        for n in nodes:
            if n["name"].lower() == node.lower():
                found_obj = True
                result = session.post("{}/api/v2/nodes/{}/start_scan.json".format(url, n["id"]), params={"label": label}).json()
                job["id"] = result["job_id"]
    elif group:
        raise NotImplementedError
    elif environment:
        raise NotImplementedError
    else:
        raise AttributeError("One of node, group, or environment must be provided.")

    if found_obj:
        if "id" in job:
            job["status"] = 0
            while job["status"] in [jobStatus["Pending"], jobStatus["Processing"]]:
                time.sleep(5)
                job = getJob(session, url, job["id"])
        else:
            raise AttributeError("Job ID was not found from the scan job.")
    else:
        raise AttributeError("Object (node, group, or environment) was not found to start the scan.")
    return job

def getJob(session, url, id):
    return session.get("{}/api/v2/jobs/{}.json".format(url, id)).json()
