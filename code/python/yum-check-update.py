#!/usr/bin/python
import json
import subprocess

# Comma delimited list of packages to exclude
exclude_list = ""

process = subprocess.Popen(["yum", "check-update", "-q", "-x", exclude_list], stdout=subprocess.PIPE)
(output, err) = process.communicate()
exit_code = process.wait()

if exit_code == 0 and output == "":
        print json.dumps({"exit_code": exit_code, "raw": "Up to date"})
else:
        print json.dumps({"exit_code": exit_code, "raw": output})
