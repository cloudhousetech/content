#!/usr/bin/python
import json
import subprocess

process = subprocess.Popen(["yum", "check-update", "-q"], stdout=subprocess.PIPE)
(output, err) = process.communicate()
exit_code = process.wait()

if exit_code == 0 and output == "":
        print "Up to date"
else:
        print json.dumps({"exit_code": exit_code, "raw": output})
