<# 
.SYNOPSIS
  Adds all repositories in a GitHub organisation to a Guardian instance.
.DESCRIPTION
  Get's all repositories using token and organisation parameters, checks existing guardian nodes and only adds any missing repositories to Guardian.
  CAVEAT: Currently uses hardcoded "connection_manager_group_id"=  1
  Requires Powershell 7.0
.PARAMETER GitHubToken
  Your API access token which can be found and generated via Personal access tokens page in GitHub Settings. Used to get repositories and provided to Guardian as access token for scans
.PARAMETER GuardianHostName
  Host name without transport scheme. e.g. cloudhouse.com or google.com
.PARAMETER GuardianToken
  API token for Guardian https://help.cloudhouse.com/upguard/using-the-api.html
.EXAMPLE
  Add-GitHubRepoNodes.ps1 -GitHubToken xyx -GitHubOrganisation yourorg -GuardianHostname yourinstance.com -GuardianToken xyz

  Basic invocation uses Default environment
.EXAMPLE
  Add-GitHubRepoNodes.ps1 -GitHubToken xyx -GitHubOrganisation yourorg -GuardianEnvironment Default -GuardianHostname yourinstance.com -GuardianToken xyz
  
  Using GuardianEnvironment parameter set as 'Default' achieves same result as EXAMPLE 1
#>
[CmdletBinding(SupportsShouldProcess)]
param (
  [Parameter(Mandatory=$true)]
  [string]$GitHubToken,
  [Parameter(Mandatory=$true)]
  [string]$GitHubOrganisation,
  [Parameter(Mandatory=$true)]
  [string]$GuardianHostName,
  [Parameter()]
  [string]$GuardianEnvironment = 'Default',
  [Parameter(Mandatory=$true)]
  [String]$GuardianToken
)
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Error "This script requires PS Version 7.0 or greater"
  return
}

$gitHubHeaders = @{Authorization = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("ignore:$GitHubToken")))"}
$reposUri = "https://api.github.com/orgs/$GitHubOrganisation/repos?per_page=100&page=1"
Write-Information "Making GET call to $reposUri"

$gitHubRepos = Invoke-RestMethod -URI $reposUri -Headers $gitHubHeaders -FollowRelLink
# $gitHubRepos has nested arrays so this flattens it before iterating
$gitHubRepos = @($gitHubRepos | %{$_})
Write-Information "  Got $($gitHubRepos.Count) repos" 

$guardianHeaders = @{Authorization="Token token=""$GuardianToken"""}
$guardianNodesUri = "https://$GuardianHostName/api/v2/nodes.json"
$allGitHubNodes  = @()
$perPage = 100
$page       = 1

try 
{
    while ($true)
    {
        $qs        = "page=$($page)&per_page=$($perPage)"
        $fullURI  = "https://$GuardianHostName/api/v2/nodes.json?$($qs)"

        Write-Information "Making GET call to $fullURI"
        $nodes = Invoke-RestMethod -Uri $fullURI -Headers $guardianHeaders
        Write-Information "  Got $($nodes.Count) nodes" 
        $totItems += $items.Count
        $allGitHubNodes += $nodes| Where-Object {$_.operating_system_id -eq 1451}
        $page += 1
        if( $nodes.Count -lt $perPage) { break }
    }
}
catch
{
    Write-Error "Exception: $($_.Exception.Message)"
}

$environments = Invoke-RestMethod 'https://dogfood.cloudhouse.com/api/v2/environments.json' -Headers $guardianHeaders -Method GET
$matchedEnvironments = $environments | Where-Object { $_.name -eq $GuardianEnvironment}
if ($matchedEnvironments.count -eq 0) {
  Write-Error "No environment found matching $GuardianEnvironment"
}
$environmentId = $environments[0].id
Write-Information "Selected environment $GuardianEnvironment with id $environmentId"
$gitHubRepos| %{
  $repo = $_
  Write-Information ("Checking {0}" -f $repo.url)
  $isExistingNode = ($allGitHubNodes | Where-Object { $_.medium_hostname -eq $repo.url }).count  -gt 0
  if ($isExistingNode){
    Write-Information ("{0} is already added" -f $repo.url)
  } else{

    Write-Information ("Adding {0}" -f $repo.url)
    
    $body = @{
      "node"= @{
        "connection_manager_group_id"=  1
        "description"=  ("The {0} repository" -f $repo.name)
        "environment_id"=  $environmentId
        "medium_hostname"=  $repo.html_url
        "medium_password"=  $GitHubToken
        "name"=  ("GitHub {0}" -f $repo.name)
        "node_type"=  "SV"
        "operating_system_family_id"=  14
        "operating_system_id"=  1451
        "short_description"=  ("The {0} repository" -f $repo.name)
      }
    }
    $jsonBody = (ConvertTo-Json $body)
    if ($PSCmdlet.ShouldProcess($jsonBody)){
      $r = Invoke-RestMethod -URI $guardianNodesUri -Headers $guardianHeaders -Body $jsonBody -Method POST -ContentType 'application/json'
    }
  }
}