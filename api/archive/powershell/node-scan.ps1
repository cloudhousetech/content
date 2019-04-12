# Ignore self-signed SSL certificates
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

try {
    $instanceUrl = "instance url"
    $apiKey = "api key"
    $secretKey = "secret key"
    $headers = @{
        'Authorization' = 'Token token="' + $apiKey + $secretKey + '"';
    }

    $nodeFQDN = "$env:computername.$env:userdnsdomain"

    $body = ''
    $node = @{
        'name' = $nodeFQDN;
        'node_type' = 'SV';
        'operating_system_family_id' = 1;
        'operating_system_id' = 125;
        'medium_type' = 7;
        'medium_hostname' = $nodeFQDN;
        'medium_port' = 5985;
        'connection_manager_group_id' = 2;
        'external_id' = $nodeFQDN;
    }

    $nodeLookup = $instanceUrl + "/api/v2/nodes/lookup.json?external_id=#{external_id}"
    $nodeCreate = $instanceUrl + "/api/v2/nodes.json"
    $nodeScan   = $instanceUrl + "/api/v2/nodes/#{node_id}/start_scan.json?label=#{tag}"

    foreach ($kvp in $node.GetEnumerator()) {
        $body += 'node[' + $kvp.Key + ']=' + $kvp.Value + '&'
    }

    $body = $body.TrimEnd('&')

    # Lookup the node to see if it already exists
    if ($nodeFQDN -ne $null -and $nodeFQDN.Length -gt 0) {

        $nodeFDQN = [uri]::EscapeDataString($nodeFQDN)
        $nodeLookup = $nodeLookup -replace("#{external_id}", $nodeFQDN)

        try {
            $lookupRes = Invoke-WebRequest $nodeLookup -Method Get -Headers $headers
            if ($lookupRes -ne $null -and $lookupRes.StatusCode -eq 200) {
                # Node exists, get its node id
                $lookupJson = $lookupRes.Content | ConvertFrom-Json
                $nodeId = $lookupJson.node_id
            } else {
                throw "upguard: failed to lookup node: " + $lookupRes
            }
        } catch { # A 404 is an error according to PowerShell
            if ($_.Exception.Message -like "*Not Found*") {
                # Create the node
                $nodeRes = Invoke-WebRequest $nodeCreate -Method Post -Headers $headers -Body $body
                if ($nodeRes -ne $null -and $nodeRes.StatusCode -eq 201) {
                    $nodeJson = $nodeRes.Content | ConvertFrom-Json
                    $nodeId = $nodeJson.id 
                } else {
                    throw "upguard: failed to create node: " + $lookupRes
                }
            } else {
                throw "upguard: failed to lookup node: " + $_.Exception.Message
            }
        }

        $nodeScan = $nodeScan -replace("#{node_id}", $nodeId)
        $nodeScan = $nodeScan -replace("#{tag}", "Logoff%20scan")
        $jobRes = Invoke-WebRequest $nodeScan -Method Post -Headers $headers
        
        if ($jobRes -ne $null -and $jobRes.StatusCode -eq 201) {
            $jobJson = $jobRes.Content | ConvertFrom-Json
            $jobId = $jobJson.job_id
            "upguard: node scan kicked off against " + $nodeFQDN + " (" + $instanceUrl + "/jobs/" + $jobId + "/show_job?show_all=true)"

        } else {
            throw "upguard: failed to kick off node scan against " + $nodeFQDN + ": " + $jobRes
        }
    } else {
        throw "upguard: could not determine node fqdn"
    }
} catch {
    $_.Exception.Message
}
