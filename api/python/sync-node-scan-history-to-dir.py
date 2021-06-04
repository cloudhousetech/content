
# pip install upguard
import upguard
import json
import os

api_key = "1234"
sec_key = "5678"
instance = "https://you.upguard.com"
dir_to_save_to = "/tmp/scans"
node_name = "My Example Node"

try:
    os.mkdir(dir_to_save_to)
except OSError as error:
    print("Dir already exists") # probably

o = upguard.Account(instance, api_key, sec_key)

# you can also find the node by ID, if you know the ID
# node = o.node_by_id(node_id)
node = o.node_by_name(node_name)

scans = node.node_scans()
for scan in scans:
    # reload the scan to load the data
    scan.load()

    print("Saving scan at " + str(scan.created_at))
    filename = dir_to_save_to + str(scan.created_at) + ".json"
    f = open(filename, "w")
    f.write(json.dumps(scan.data))
    f.close()

print("DONE")


