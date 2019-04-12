#!/usr/bin/python

import json
import subprocess

command_list = [
	{'command_name': ['ls'], 'command_args': ['-la', '/var/log']},
	{'command_name': ['hostname'], 'command_args': []},
	{'command_name': ['find'], 'command_args': ['/var/log', '-name', '*.conf']}
]

def generate_scan(commands):
	output_data = {
		'Commands': {}
	}

	for c in commands:
		process = subprocess.Popen(c['command_name'] + c['command_args'], stdout=subprocess.PIPE)
		process.stdout.flush()
		process_output = process.communicate()
		output_data['Commands'][c['command_name'][0]] = {
				'Output': {
						'StdOut': process_output[0]
					}
			}
		

	print(json.dumps(output_data, sort_keys=True,
						indent=4, separators=(',', ': ')))

generate_scan(command_list)
