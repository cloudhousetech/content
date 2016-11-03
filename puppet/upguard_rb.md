## IQ Ticket Generation

### Sequence Diagram

```sequence
PDB->>upguard.rb: 1. Node changed?
upguard.rb--PDB: 2. Node OS?
PDB->>upguard.rb: OS
upguard.rb--PDB: 3. Node Role?
PDB->>upguard.rb: Role
upguard.rb->UpGuard: 4. Node group present?
Note right of UpGuard: Create if not
UpGuard--upguard.rb: Node group id
upguard.rb->UpGuard: 5. Node present?
Note right of UpGuard: Create if not
UpGuard--upguard.rb: Node id
upguard.rb->UpGuard: 6. Add node to group
UpGuard--upguard.rb: Node added to group
upguard.rb->UpGuard: 7. Config scan
Note right of UpGuard: Policies evaluated
UpGuard--upguard.rb: Job id
UpGuard->Jira: 8. Ticket present?
Note right of Jira: If not, create IQ ticket with policy results
Jira--UpGuard: Ticket id
```

### Messages

> **Note:**

> - All message response types are JSON formatted unless otherwise specified.
> - Messages with a `?` present a response decision for the recipient system.   
> - Values encased in curly braces `#{}` are variables pointing to the current Puppet DB, UpGuard or Jira instance.
> - The latest version of `upguard.rb` can be found [here](https://github.com/ScriptRock/content/blob/master/puppet/upguard.rb).

#### 1. Node changed?

Any changes that Puppet makes to a node will trigger the execution of `upguard.rb`,  a [custom report processor](https://docs.puppet.com/puppet/latest/reference/reporting_write_processors.html).  This report is executed after a Puppet agent run has completed and ensures that Puppet and UpGuard nodes and roles remain synchronized.

| Type          | Method   | Interface                 | Response
| :------------ | :------- | :------------------------ | :-------
| Asynchronous  | Internal | `Puppet::Reports.status`  | Changed

#### 2. Node OS?

An additional call to the Puppet DB is required to determine the nodes operating system as this is not a variable that is exposed through the `Puppet::Reports` class. Nodes created in UpGuard require the operating system field to be set.

| Type          | Method   | Interface                                             | Response
| :------------ | :------- | :---------------------------------------------------- | :-------
| Synchronous   | GET      | `#{PUPPETDB_URL}/pdb/query/v4/facts/operatingsystem`  | OS type

#### 3. Node Role?

As with determining the nodes operating system, an additional call to the Puppet DB is required to determine the nodes role (via trusted facts).

| Type          | Method   | Interface                                                       | Response
| :------------ | :------- | :-------------------------------------------------------------- | :-------
| Synchronous   | GET      | `#{PUPPETDB_URL}/pdb/query/v4/nodes/#{node_ip_hostname}/facts`  | Node role 

#### 4. Node group present?

Roles in Puppet are synonymous to node groups in UpGuard. Any roles that exist in Puppet should exist as a node group in UpGuard. An attempt is made to add the node group to UpGuard, if the node group already exists its id will be returned.

| Type          | Method   | Interface                            | Response
| :------------ | :------- | :----------------------------------- | :-------
| Synchronous   | POST     | `#{UPGUARD_URL}/api/v2/node_groups`  | Node group id

#### 5. Node present?

Any nodes that are being changed by Puppet will need to be monitored by UpGuard. With the node's operating system and role details determined above the node can be created in UpGuard, keeping Puppet and UpGuard nodes synchronized. If the node already exists in UpGuard, its id will be returned.

| Type          | Method   | Interface                     | Response
| :------------ | :------- | :---------------------------- | :-------
| Synchronous   | POST     | `#{UPGUARD_UR}/api/v2/nodes`  | Node id

#### 6. Add node to group

Attaching the node to a node group in UpGuard will allow it to automatically inherit the relevent scan options and policies attached to the node group. Subsequent configuration scans of the node will allow policy results to be determined. This step is the last in synchronizing a Puppet node (with a role) to an UpGuard node (with one or many node groups).

| Type          | Method   | Interface                     | Response
| :------------ | :------- | :---------------------------- | :-------
| Synchronous   | POST     | `#{UPGUARD_URL}/api/v2/node_groups/#{node_group_id}/add_node.json?node_id=#{node_id}`  | Node id

#### 7. Config scan

Configuration scans allow for a nodes known configuration state to be tracked over time. Once a node's state is known to UpGuard after its first successful configuration scan, policy results are determined automatically. Policies in UpGuard allow for users to determine a nodes desired state and can be written in advance of the node or role existing in Puppet allowing users to write tests in advance or in conjunction to Puppet roles.

| Type          | Method   | Interface                                                 | Response
| :------------ | :------- | :-------------------------------------------------------- | :-------
| Synchronous   | POST     | `#{UPGUARD_URL}/api/v2/nodes/#{node_id}/start_scan.json`  | Job id

#### 8. Ticket present?

Policy success and failure results, on a per node basis, are captured through IQ tickets in Jira. If an IQ ticket already exists for a node, another will not be created. An IQ ticket with policy failure results can enter into a Jira workflow where it can be assigned to a user or group for remediation. In this case, the Puppet role would likely be reviewed and modified rather than the cited node. A new node with the updated Puppet role can then be supplied for subsequent retesting.

| Type          | Method   | Interface                                                      | Response
| :------------ | :------- | :------------------------------------------------------------- | :-------
| Synchronous   | POST     | `#{JIRA_URL}/rest/api/2/issue`                                 | Ticket id

