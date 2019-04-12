# For every node in an UpGuard instance, set the hostname to match the display name
# Use -dry_run to see what would be changed

param (
    [Parameter(Mandatory=$true)][string]$target_url,
    [Parameter(Mandatory=$true)][string]$api_key,
    [Parameter(Mandatory=$true)][string]$secret_key,
    [switch]$dry_run
 )

$headers = @{'Authorization' = 'Token token="' + $api_key + $secret_key + '"';
                 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

$nodes = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes.json?page=1&per_page=500") -Headers $headers -Method "GET"

if ($nodes.StatusCode > 400)
{
  throw [System.Exception] $nodes.StatusCode.ToString() +
    " " + $nodes.StatusDescription
}
else
{
    $nodes = ConvertFrom-Json -InputObject $nodes
    $total = $nodes.Count
    $count = 1
    ForEach ($node in $nodes)
    {
        $hostname = $node.name
        "Setting node {0} hostname to {1} ({2}/{3})" -f $node.name, $hostname, $count, $total
        $body = @{"node" = @{"medium_hostname" = $hostname}}
        $body = ConvertTo-Json -InputObject $body
        
        if ($dry_run -eq $false)
        {
            $response = Invoke-WebRequest -Uri ("https://" + $target_url + "/api/v2/nodes/ " + $node.id + ".json") -Body $body -Headers $headers -Method "PUT"
            if ($response.StatusCode > 400)
            {
                throw [System.Exception] $response.StatusCode.ToString() + " " + $response.StatusDescription
            }
        }

        $count = $count + 1
    }
}
