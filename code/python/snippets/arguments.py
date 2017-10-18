"""
Add command line arguments to your script.

This snippet adds the default command line arguments required for any interaction with the UpGuard API.

To Use:

1. Copy snippet to the top of your script
2. Populate description (this is shown when running `--help`)
3. Access arguments with `args` object, for example: `args.target_url`
"""

import argparse

parser = argparse.ArgumentParser(description='Retrieve a list of open User Tasks and their associated nodes')
parser.add_argument('--target-url', required=True, help='URL for the UpGuard instance')
parser.add_argument('--api-key', required=True, help='API key for the UpGuard instance')
parser.add_argument('--secret-key', required=True, help='Secret key for the UpGuard instance')
parser.add_argument('--insecure', action='store_true', help='Ignore SSL certificate checks')
args = parser.parse_args()
