#!/usr/bin/python
# -*- coding: utf-8 -*-

# (c) 2016, Brad Gibson <napalm255@gmail.com>
#
# This file is a 3rd Party module for Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

"""Ansible Upguard Module."""
from __future__ import absolute_import, unicode_literals

ANSIBLE_METADATA = {'status': ['preview'],
                    'supported_by': 'community',
                    'version': '1.0'}

DOCUMENTATION = '''
---
module: upguard_node
author: "Brad Gibson, @napalm255"
version_added: "2.3"
short_description: Manage UpGuard Node
requirements:
    - requests
description:
    - Manage UpGuard node.
    - CRUD supported.
    - Add node to node group.
    - Create job to scan node.
    - Check mode supported.
options:
    url:
        required: true
        description:
            - The url of the Upguard Management Console. Port is optional.
            - i.e.  https://upguard.example.com[:8443]
    username:
        required: true
        description:
            - The username of the Upguard Management Console.
    password:
        required: true
        description:
            - The password of the Upguard Management Console.
    name:
        required: true
        description:
            - The name of the node.
    node_type:
        required: true
        default: SV
        choices:
            - "SV: Server"
            - "DT: Desktop"
            - "SW: Network Switch"
            - "FW: Firewall"
            - "RT: Router"
            - "PH: Smart Phone"
            - "RB: Robot"
            - "SS: SAN Storage"
            - "WS: Website"
        description:
            - The node type. Use two letter code.
    gather_facts:
        required: false
        default: false
        choices:
            - true
            - false
        description:
            - Return node and group details.
    state:
        required: false
        choices:
            - present
            - absent
        description:
            - Create or delete node.
            - When C(state=present) facts will be gathered.
    properties:
        required: false
        choices:
            - dict
        description:
            - Properties of the node.
            - See U(https://support.upguard.com/upguard/nodes-api-v2.html#create).
            - Invalid or misspelled properties will be ignored.
            - Property values are not verified for legitimacy. They will be tried as-is.
    groups:
        required: false
        choices:
            - list
        description:
            - List of group ids and/or group names in which to add the node.
    scan:
        required: false
        default: false
        choices:
            - true
            - false
        description:
            - Create a job to scan the node.
    scan_label:
        required: false
        default: ansible initiated
        description:
            - Assign a label to the scan job.
    scan_timeout:
        required: false
        default: 120
        description:
            - Timeout in seconds to wait for the scan job.
            - The task will fail if the timeout is reached.
    validate_certs:
        required: false
        default: true
        choices:
            - true
            - false
        description:
            - Allows connection when SSL certificates are not valid.
            - Set to false when certificates are not trusted.
'''

EXAMPLES = '''
# create/update node
- upguard_node:
    url: "https://upguard.example.com"
    username: "upguard_user"
    password: "upguard_pass"
    name: "node_name"
    node_type: "SV"
    state: "present"
    properties:
        short_description: web server
        medium_type: 3
        medium_port: 22
        operating_system_family_id: 2

# delete node
- upguard_node:
    url: "https://upguard.example.com"
    username: "upguard_user"
    password: "upguard_pass"
    name: "node_name"
    node_type: "SV"
    state: "absent"

# create/update, add to groups and scan node
- upguard_node:
    url: "https://upguard.example.com"
    username: "upguard_user"
    password: "upguard_pass"
    name: "node_name"
    node_type: "SV"
    state: "present"
    scan: true
    groups:
      - 100
      - GroupName

# scan node
- upguard_node:
    url: "https://upguard.example.com"
    username: "upguard_user"
    password: "upguard_pass"
    name: "node_name"
    node_type: "SV"
    scan: true

# gather facts
- upguard_node:
    url: "https://upguard.example.com"
    username: "upguard_user"
    password: "upguard_pass"
    name: "node_name"
    node_type: "SV"
    gather_facts: true
  register: results

'''

RETURN = '''
---
node:
    description: node details
    returned: either state is present or gather_facts is true
    type: dict
    sample: {
        "alternate_password": null,
        "connect_mode": "f",
        "connection_manager_group_id": null,
        "created_at": "2017-02-08T02:16:31.962-05:00",
        "created_by": 8,
        "description": null,
        "discovery_type": null,
        "environment_id": 7,
        "external_id": null,
        "id": 1120,
        "info": null,
        "ip_address": null,
        "last_scan_id": null,
        "last_scan_status": null,
        "last_vuln_scan_at": null,
        "mac_address": null,
        "medium_connection_fail_count": 0,
        "medium_group": null,
        "medium_hostname": null,
        "medium_info": {},
        "medium_password": null,
        "medium_port": 22,
        "medium_ssl_cert": null,
        "medium_ssl_privkey": null,
        "medium_type": 3,
        "medium_username": null,
        "name": "SOME_NODE_NAME",
        "node_type": "SV",
        "online": false,
        "operating_system_family_id": null,
        "operating_system_id": null,
        "organisation_id": 4,
        "primary_node_group_id": null,
        "public": false,
        "scan_options": null,
        "short_description": "",
        "status": 1,
        "updated_at": "2017-02-08T18:07:19.502-05:00",
        "updated_by": 8,
        "url": null,
        "uuid": "686ddbc5-0f6a-4641-af41-5e99f62fe2ac"
    }

groups:
    description: group details
    returned: groups are defined and either state is present or gather_facts is true
    type: dict
    sample: {
        "102": {
            "created_at": "2017-02-08T00:57:47.817-05:00",
            "description": null,
            "diff_notify": false,
            "external_id": null,
            "id": 102,
            "name": "SOME_GROUP_NAME",
            "node_rules": null,
            "organisation_id": 4,
            "owner_id": null,
            "scan_options": '{\"scan_directory_options\":[]}',
            "search_query": null,
            "status": 1,
            "updated_at": "2017-02-08T00:57:47.817-05:00"
        }
    }

scan:
    description: scan job details
    returned: scan is true
    type: dict
    sample: {
        "created_at": "2017-02-08T23:46:30.143-05:00",
        "created_by": 8,
        "diff_stats": null,
        "id": 780,
        "organisation_id": 4,
        "scheduled_job_id": null,
        "source_id": 1117,
        "source_name": "SOME_NODE_NAME",
        "source_type": 11,
        "stats": null,
        "status": -1,
        "updated_at": "2017-02-08T23:46:37.133-05:00",
        "updated_by": 8,
        "upload_node_id": 1117
    }

'''

REQUIRED_MODULES = dict()
try:
    import time
    import operator
    import sys
    import json
    # pylint: disable = redefined-builtin, redefined-variable-type
    # pylint: disable = invalid-name, undefined-variable
    if sys.version_info[0] == 2:
        # Python 2
        # strings and ints
        text_type = unicode  # noqa
        string_types = (str, unicode)  # noqa
        integer_types = (int, long)  # noqa
        # lazy iterators
        range = xrange  # noqa
        from itertools import izip as zip  # noqa
        iteritems = operator.methodcaller('iteritems')  # noqa
        iterkeys = operator.methodcaller('iterkeys')  # noqa
        itervalues = operator.methodcaller('itervalues')  # noqa
    else:
        # Python 3
        # strings and ints
        text_type = str  # noqa
        string_types = (str,)  # noqa
        integer_types = (int,)  # noqa
        # lazy iterators
        zip = zip  # noqa
        range = range  # noqa
        iteritems = operator.methodcaller('items')  # noqa
        iterkeys = operator.methodcaller('keys')  # noqa
        itervalues = operator.methodcaller('values')  # noqa
except ImportError:
    pass

try:
    from ansible.module_utils.basic import AnsibleModule  # noqa
    REQUIRED_MODULES['ansible'] = True
except ImportError:
    REQUIRED_MODULES['ansible'] = False

try:
    import requests
    REQUIRED_MODULES['requests'] = True
except ImportError:
    REQUIRED_MODULES['requests'] = False


class UpguardNode(object):
    """Upguard Class."""

    def __init__(self, module):
        """Init."""
        self.module = module
        # turn module params into arg
        self.arg = lambda: None
        for arg in self.module.params:
            setattr(self.arg, arg, self.module.params[arg])
        # set defaults
        self.arg.name = self.arg.name.upper()
        # strip trailing slash and append api version
        self.arg.url = self.arg.url.rstrip('/') + '/api/v2'
        # define default results
        self.results = {'changed': False,
                        'failed': False}
        # define medium types mapping
        self.medium_types = {'AGENT': 1, 'SSH': 3, 'TELNET': 5, 'HTTPS': 6,
                             'WINRM': 7, 'SERVICE': 8, 'WEB': 9}
        # define node types mapping
        self.node_types = {'SV': 'Server', 'DT': 'Desktop',
                           'SW': 'Network Switch', 'FW': 'Firewall',
                           'RT': 'Router', 'PH': 'Smart Phone',
                           'RB': 'Robot', 'SS': 'SAN Storage', 'WS': 'Website'}
        # define nodes status codes mapping
        self.status_codes = {0: 'PENDING', 1: 'PROCESSING', 2: 'SUCCESS',
                             3: 'ASSIGNED', 5: 'ACTIONED', 9: 'FAILURE',
                             10: 'OFFLINE', 20: 'CANCELLED', 55: 'TIMEOUT',
                             88: 'ERROR', 99: 'EXCEPTION'}

    def __enter__(self):
        """Enter."""
        return self

    def __exit__(self, type, value, traceback):
        """Exit."""
        # pylint: disable=redefined-builtin
        return

    def _connect(self, url=None, data=None, params=None, method='get'):
        """Connect and return request."""
        req = getattr(requests, str(method.lower()))
        url = self.arg.url + str(url)
        headers = {'Accept': 'application/json',
                   'Content-Type': 'application/json'}
        auth = (self.arg.username, self.arg.password)
        verify = bool(self.arg.validate_certs)
        try:
            response = req(url, headers=headers, auth=auth,
                           params=params, json=data, verify=verify)
        except requests.exceptions.RequestException as ex:
            self.module.fail_json(msg='failed to connect',
                                  error=str(ex))

        return response

    def group_details(self, group_id):
        """Return group details."""
        details = {}
        url = '/node_groups/{}.json'.format(group_id)
        try:
            response = self._connect(url)
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed querying node group details',
                                  error=str(ex))
        if response.content:
            details = json.loads(response.content)

        return details

    def group_nodes(self, group_id):
        """Return group nodes."""
        url = '/node_groups/{}/nodes.json'.format(group_id)
        try:
            response = self._connect(url)
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed querying node group nodes',
                                  error=str(ex))

        nodes = json.loads(response.content)

        return nodes

    def group_id(self, group_name):
        """Return group id."""
        url = '/node_groups/lookup.json'
        params = {'name': group_name}
        try:
            response = self._connect(url, params=params)
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='group does not exist',
                                  error=str(ex))

        group_id = int(json.loads(response.content)['node_group_id'])

        return group_id

    def group_add_node(self, group_id):
        """Add node to group."""
        added = False
        url = '/node_groups/{}/add_nodes.json'.format(group_id)
        params = {'node_ids[]': self.node_id}
        try:
            response = self._connect(url, params=params, method='post')
            response.raise_for_status()
            if response.status_code == 201:
                added = True
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed adding node to group',
                                  error=str(ex))

        return added

    @property
    def node_id(self):
        """Return node id."""
        url = '/nodes/lookup.json'
        params = {'name': self.arg.name}
        try:
            response = self._connect(url, params=params)
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='node does not exist.',
                                  error=str(ex))

        node_id = int(json.loads(response.content)['node_id'])

        return node_id

    @property
    def node(self):
        """Return node details."""
        node_id = self.node_id
        url = '/nodes/{}.json'.format(node_id)
        try:
            response = self._connect(url)
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed querying node details',
                                  error=str(ex))

        details = json.loads(response.content)

        return details

    @property
    def exists(self):
        """Node exists."""
        node_exists = True
        url = '/nodes/lookup.json'
        params = {'name': self.arg.name}
        try:
            response = self._connect(url, params=params)
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            err = str(ex)
            if '404' in err:
                node_exists = False
            else:
                self.module.fail_json(msg=str(ex))

        return node_exists

    @property
    def matches(self):
        """Match node to properties."""
        node_matches = True
        node_details = self.node

        # define properties to match
        properties = {'name': self.arg.name,
                      'node_type': self.arg.node_type}
        properties.update(self.arg.properties)

        # match properties
        for key, value in iteritems(properties):
            if key in node_details and value != node_details[key]:
                node_matches = False

        # match groups
        if self.arg.groups is not None:
            for group in self.arg.groups:
                group_id = group
                if isinstance(group, str):
                    group_id = self.group_id(group)
                group_nodes = self.group_nodes(group_id)
                if 'error' in group_nodes:
                    self.module.fail_json(msg='failed checking groups',
                                          error=group_nodes['error'])
                group_matches = [group_node for group_node in group_nodes if
                                 group_node['id'] == self.node_id]
                if not group_matches:
                    node_matches = False

        return node_matches

    def create(self):
        """Create node."""
        url = '/nodes.json'
        # define properties to set
        properties = {'name': self.arg.name,
                      'node_type': self.arg.node_type}
        properties.update(self.arg.properties)
        try:
            response = self._connect(url, method='post',
                                     data={'node': properties})
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed creating node',
                                  error=str(ex))

        results = json.loads(response.content)

        return results

    def update(self):
        """Update node."""
        updated = False
        node_id = self.node_id
        url = '/nodes/{}.json'.format(node_id)
        # define properties to set
        properties = {'node_type': self.arg.node_type}
        properties.update(self.arg.properties)
        try:
            response = self._connect(url, method='put',
                                     data={'node': properties})
            response.raise_for_status()
            if response.status_code == 204:
                updated = True
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed updating node',
                                  error=str(ex))

        return updated

    def delete(self):
        """Delete node."""
        deleted = False
        node_id = self.node_id
        url = '/nodes/{}.json'.format(node_id)
        try:
            response = self._connect(url, method='delete')
            response.raise_for_status()
            if response.status_code == 204:
                deleted = True
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed deleting node',
                                  error=str(ex))

        return deleted

    def present(self):
        """Set state to present."""
        node_changed = False
        # create
        if not self.exists:
            self.create()
            node_changed = True
        # update
        elif self.exists and not self.matches:
            self.update()
            node_changed = True
        # node groups
        if self.arg.groups is not None and not self.matches:
            for group in self.arg.groups:
                group_id = group
                if isinstance(group, str):
                    group_id = self.group_id(group)
                self.group_add_node(group_id)
        # validate
        if not self.exists or not self.matches:
            self.module.fail_json(msg="error validating state is present.")
        # gather facts
        self.gather_facts()

        return node_changed

    def absent(self):
        """Set state to absent."""
        node_changed = False
        # delete
        if self.exists:
            self.delete()
            node_changed = True
        # validate
        if self.exists:
            self.module.fail_json(msg="error validating state is absent.")

        return node_changed

    def gather_facts(self):
        """Gather facts."""
        if self.exists:
            self.results['node'] = self.node
        else:
            self.module.fail_json(msg='node does not exist.')

        if self.arg.groups is not None:
            self.results['groups'] = dict()
            for group in self.arg.groups:
                group_id = group
                if isinstance(group, str):
                    group_id = self.group_id(group)
                self.results['groups'][group_id] = self.group_details(group_id)

        return

    def job(self, job_id):
        """Return job."""
        url = '/jobs/{}.json'.format(job_id)
        try:
            response = self._connect(url)
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed querying job',
                                  error=str(ex))

        results = json.loads(response.content)

        return results

    def scan(self):
        """Scan node."""
        job = None
        node_id = self.node_id
        label = self.arg.scan_label
        timeout = self.arg.scan_timeout
        url = '/nodes/{}/start_scan.json'.format(node_id)
        params = {'label': label}
        try:
            response = self._connect(url, method='post')
            response.raise_for_status()
        except requests.exceptions.HTTPError as ex:
            self.module.fail_json(msg='failed to create scan',
                                  error=str(ex))

        job_id = int(json.loads(response.content)['job_id'])

        for count in range(timeout + 1):
            job = self.job(job_id)
            status = job['status']
            if status == 0 or status == 1:
                if count == timeout:
                    msg = 'timed out after {}s waiting for scan'.format(count)
                    self.module.fail_json(msg=msg, scan=job)
                time.sleep(1)
            elif status == 2:
                break
            elif status == -1 or status > 2:
                self.module.fail_json(msg='scan failed', scan=job)

        return job


def main():
    """Main."""
    module = AnsibleModule(
        argument_spec=dict(
            url=dict(type='str', required=True),
            username=dict(type='str', required=True),
            password=dict(type='str', required=True, no_log=True),
            gather_facts=dict(type='bool', default=False),
            name=dict(type='str', required=True),
            node_type=dict(type='str', default='SV'),
            state=dict(type='str', default=None),
            properties=dict(type='dict', default=None),
            groups=dict(type='list', default=None),
            scan=dict(type='bool', default=False),
            scan_label=dict(type='str', default='ansible initiated'),
            scan_timeout=dict(type='int', default=120),
            validate_certs=dict(type='bool', default=True),
        ),
        supports_check_mode=True
    )

    # check dependencies
    for requirement in REQUIRED_MODULES:
        if not requirement:
            module.fail_json(msg='%s not installed.' % (requirement))

    # check mode
    if module.check_mode:
        with UpguardNode(module) as upguard:
            if not upguard.exists or not upguard.matches:
                upguard.results['changed'] = True
            module.exit_json(**upguard.results)

    # gather facts
    if module.params['gather_facts']:
        with UpguardNode(module) as upguard:
            upguard.gather_facts()
            module.exit_json(**upguard.results)

    # process
    with UpguardNode(module) as upguard:
        state = module.params['state']
        scan = module.params['scan']
        # absent
        if 'absent' in state:
            upguard.results['changed'] = upguard.absent()
            module.exit_json(**upguard.results)
        # present
        if 'present' in state:
            upguard.results['changed'] = upguard.present()
        # scan
        if scan:
            upguard.results['scan'] = upguard.scan()
        module.exit_json(**upguard.results)

    # if no results, fail
    module.exit_json(**{'failed': True, 'msg': 'nothing to do'})


if __name__ == '__main__':
    main()
