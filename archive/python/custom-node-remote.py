#!/usr/bin/python

import json
import subprocess

command_list = [
	{'command_name': ['ls'], 'command_args': ['-la', '/var/log']},
	{'command_name': ['hostname'], 'command_args': []},
	{'command_name': ['find'], 'command_args': ['/var/log', '-name', '*.conf']}
]

def generate_scan(commands, host=None):
	output_data = {
		'Commands': {}
	}

	for c in commands:
		command_output = execute_command(c, host)
		output_data['Commands'][c['command_name'][0]] = {
				'Output': {
						'StdOut': command_output
					}
			}
		

	print(json.dumps(output_data, sort_keys=True,
						indent=4, separators=(',', ': ')))

def execute_command(command, host=None):
	if host is not None:
		ssh = subprocess.Popen(["ssh", "%s" % host] + command['command_name'] + command['command_args'],
	                       shell=False,
	                       stdout=subprocess.PIPE,
	                       stderr=subprocess.PIPE)
		ssh.stdout.flush()
		result, error = ssh.communicate()
		if result == []:
		    print >> sys.stderr, "ERROR: %s" % error
		    return None
		else:
		    return result
	else:
		process = subprocess.Popen(command['command_name'] + command['command_args'], stdout=subprocess.PIPE)
		process.stdout.flush()
		process_output, error = process.communicate()
		if process_output == []:
		    print >> sys.stderr, "ERROR: %s" % error
		    return None
		else:
		    return process_output

generate_scan(command_list, "user@the.server.address")
