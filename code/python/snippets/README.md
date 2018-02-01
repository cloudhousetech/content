# Overview

A collection of functions that can be used to interact with the UpGuard API.

# Requirements

In order to run the `template.py` file, you will need to install the required packages in `requirements.txt`:

```
pip install -r requirements.txt
```

# Files

There are two files here:

* `template.py`: Driving script to demonstrate how to use the functions in `snippets.py`
* `snippets.py`: A collection of functions that can be used in other scripts.

# Usage

You can import any functions from the `snippets.py` file for use in your own script.

First, you will need to import the `getBrowser()` function in order to setup the connection:

```
from snippets import getBrowser
```

Then you can create the connection by passing the URL and the optional `insecure` boolean (which defaults to `False`):

```
browser = getBrowser(target_url="https://appliance.upguard.org", insecure=False)
```

You have a connection setup, but you will need your authentication token in order to make calls to the instance. This is a combination of your api and secret key with no spaces in between:

```
token = "{}{}".format("api_key", "secret_key")
```

Now you have a connection and token you can use to make API calls. For example, if you want to get a list of all the nodes:

```
from snippets import getNodes
nodes = getNodes(browser=browser, token=token, details=True)
print("\n\nNodes\n-----")
for node in nodes:
    print("{}\n{}".format(node["name"], node))
```

Refer to the `template.py` file for more examples.
