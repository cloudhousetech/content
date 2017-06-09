## UpGuard Configuration Query Tool

### Description

This tool can be used to query for configuration in UpGuard in real-time.
Current scan data is used to make querying fast and resource lean. An UpGuard node group ID must be specified.

### Version History

| Version       | Date           | Release Notes  |
| :------------ | :--------------| :--------------|
| v0.1          | June 7, 2017   | Initial support for line-in-file and inventory searching. |

### Parameters

There are currently two parameter sets supported, "Inventory" and "Files". Parameters from these parameter sets are exclusive.

#### Required

| Parameter       | Description  |
| --------------- | :------------| 
| node\_group\_id | The node group id that you are wanting to scope your query searching on. The "All Nodes" node group id can also be used to query for configuration across all nodes if required. The node group id can be found the URL of your UpGuard appliance, after selecting a particular node group from the UI.     |

#### Inventory

| Parameter       | Description  |
| --------------- | :------------| 
| inventory\_ci   | The name of the configuration item (CI) as it appears in the UpGuard UI under the "Inventory" scan section heading. Examples include: `agent_version`, `architecture`, `os_distro_name`, `os_distro_version`, `os_release_version`, `osfamily` and `timezone`.|
| inventory\_ci\_value | The expected value of the CI. Regular expressions are supported. For version checking, `.\` can be used to escape a period e.g. `v10\.1`. It is recommend to remove whitespace from your regular expressions and use a `.+` instead e.g. `hostname.+ipAddress` or to use quotation marks. Expressions are case insensitive by default.

#### Files

| Parameter       | Description  |
| --------------- | :------------| 
| file\_name       | The full path of the file you are wanting to check for a particular line-in-file e.g. `/etc/hosts`. Quotations can be used for file paths that have spaces.|
| file\_line\_expected | The line in the file specified that is expected to be present. Regular expressions are supported e.g. `"line in my.+file"`. It should be noted that the file needs to be scanned for by UpGuard before using this query. Most configuration files (and their contents) should already be scanned for by UpGuard. If a file is not being scanned, please review your UpGuard scan options.

### Usage Examples

> Are all my servers in the PDT time zone?

`.\ci-query.ps1 -node_group_id 10 -inventory_ci "timezone" -inventory_ci_value "PDT"`

``` plain
=================================================
Starting UpGuard Configuration Utility v0.1
Getting list of nodes in node group '10'...
...Done
Checking 'timezone' equals 'EST' across 2 nodes...
==================================================
serverA, value does not match (actual 'PST')
serverB, value matches
```

> Are all my servers at a specific patch level?

`.\ci-query.ps1 -node_group_id 10 -inventory_ci "os_distro_version" -inventory_ci_value "11.4"`

``` plain
=================================================
Starting UpGuard Configuration Utility v0.1
Getting list of nodes in node group '10'...
...Done
Checking 'os_distro_version' equals '11.4' across 2 nodes...
==================================================
serverA, value does not match (actual '11')
serverB, value matches
```

> Do all the nodes in my production frontend node group have the same entry in /etc/hosts?

`.\ci-query.ps1 -node_group_id 10 -file_name "/etc/hosts" -file_line_expected "ipAddress.+hostName"`

``` plain
=================================================
Starting UpGuard Configuration Utility v0.1
Getting list of nodes in node group '10'...
...Done
Checking '/etc/hosts' equals 'idAddress.+hostName' across 2 nodes...
==================================================
serverA, value matches
serverB, value matches
```
