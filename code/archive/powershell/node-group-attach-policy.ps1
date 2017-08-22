########################################################################################
# Author: UpGuard                                                                      #
# Description: This script will add a policy (latest policy version) to a node group.  #
# Last updated: April 26, 2017                                                         #
########################################################################################

# Setup API
$upGuardServer = 'https://your.instance.url'
$secretKey = '<< secret key >>'
$serviceAccount = '<< api key >>'

# Setup variables
$NodeGroupID = x            # The node group you are wanting to attach the policy to.
$policyId = y               # The policy to attach.

# Uncomment if using a self-signed certificate
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$headers = @{'Authorization' = 'Token token="' + $serviceAccount + $secretKey + '"'
             'Accept' = 'application/json'
             'Content-Type' = 'application/json'
            }

# Make an API call to query the "last" policy version Id.
$getPolicyVersionsCall = $upGuardServer + "/api/v2/policies/" + $policyId + "/versions"
$policyVersions = Invoke-RestMethod -Uri $getPolicyVersionsCall -Headers $headers -Method Get

"Policy versions found for policy id " + $policyId + " ..."
$policyVersions

# Policy version id at array index -1 is the "latest" policy version
$latestPolicyVersionId = 0
if ($policyVersions -and $policyVersions[-1]) {
    $latestPolicyVersionId = ($policyVersions[-1]).id
}

# If this is stil 0 (the default value), then something has gone wrong.
if ($latestPolicyVersionId -eq 0) {
    "Error: latest policy version not found, quitting."
    return
} else {
    "Latest policy version id is " + $latestPolicyVersionId
}

# Make an API call to attach the latest policy version to the node group.
$addPVToNodeGroupCall = $upGuardServer + "/api/v2/node_groups/"+$NodeGroupID + "/add_policy_version?policy_version_id=" + $latestPolicyVersionId
try {
    $addPVToNodeGroup = Invoke-RestMethod -Uri $addPVToNodeGroupCall -Headers $headers -Method post
    "Attached policy_version_id " + $addPVToNodeGroup.policy_version_id + " to node_group_id " + $addPVToNodeGroup.node_group_id
} catch {
    "Policy version already attached or API call has invalid parameters."
}
