# Overview

A collection of functions that can be used to interact with the UpGuard API using the requests package.

# Requirements

In order to run the `template.py` file or use the `snippets.py` (which uses the `requests` library), you will need to install the required packages in `requirements.txt`:

```
pip install -r requirements.txt
```

# Files

There are two files here:

* `template.py`: Driving script to demonstrate how to use the functions in `snippets.py`
* `snippets.py`: A collection of functions that can be used in other scripts.

# Usage

You can import any functions from the `snippets.py` file for use in your own script.

First, you will need to import the `getSession()` function in order to setup the connection:

```
from snippets import getSession
```

Then you can create the session by passing the API key, secret key, and the optional `insecure` boolean (which defaults to `False`):

```
session = getSession(
    api_key="api_key",
    secret_key="secret_key",
    insecure=False)
```

You now have a session setup to make API calls. For example, if you want to get a list of all the nodes:

```
from snippets import getNodes
nodes = getNodes(session=session, url="https://appliance.upguard.org", details=True)
print("\n\nNodes\n-----")
for node in nodes:
    print("{}\n{}".format(node["name"], node))
```

Refer to the `template.py` file for more examples.
