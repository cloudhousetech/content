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
  [Parameter(Mandatory=$true)]
  [String]$GuardianToken,
  [Parameter()]
  [string]$GuardianEnvironment = 'Default',
  [Parameter()]
  [string]$CMGroupName = 'Default'
)
$ErrorActionPreference = 'Stop'
$guardianHeaders = @{Authorization="Token token=""$GuardianToken"""}

if ($PSVersionTable.PSVersion.Major -lt 7) {
  Write-Error "This script requires PS Version 7.0 or greater"
  return
}

function Get-GitHubRepos {
  $gitHubHeaders = @{Authorization = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("ignore:$GitHubToken")))"}
  $reposUri = "https://api.github.com/orgs/$GitHubOrganisation/repos?per_page=100&page=1"
  Write-Information "Making GET call to $reposUri"
  $gitHubRepos = Invoke-RestMethod -URI $reposUri -Headers $gitHubHeaders -FollowRelLink
  # $gitHubRepos has nested arrays so this flattens it before iterating
  $gitHubRepos = @($gitHubRepos | %{$_})
  Write-Information "  Got $($gitHubRepos.Count) repos" 
  $gitHubRepos
}

function Get-GuardianApiItems {
  param (
    [string]$uri
  )
  
  $pageParams = @{per_page=100000}
  $fullURI  = "https://$GuardianHostName/api/v2/$uri" 
  Write-Information "Making GET call to $fullURI"
  $items = Invoke-RestMethod -Uri $fullURI -Headers $guardianHeaders -Body $pageParams
  Write-Information "  Got $($items.Count) items" 
  if( $items.Count -eq $perPage) { 
    Write-Error "This script doesn't fetch more items than $perPage from Guardian, you can increase the number or iterate smaller pages"
  }
  $items
}

$gitHubRepos = Get-GitHubRepos

$gitHubNodes = Get-GuardianApiItems 'nodes.json' | Where-Object {$_.operating_system_id -eq 1451}

$matchedEnvironments = Get-GuardianApiItems 'environments.json' | Where-Object { $_.name -eq $GuardianEnvironment}
if ($matchedEnvironments.count -eq 0) {
  Write-Error "No environment found matching $GuardianEnvironment"
}
$environmentId = $matchedEnvironments[0].id
Write-Information "Selected environment $GuardianEnvironment with id $environmentId"

$matchedCMGroups = Get-GuardianApiItems 'connection_manager_groups.json' | Where-Object { $_.name -eq $CMGroupName}
if ($matchedCMGroups.count -eq 0) {
  Write-Error "No environment found matching $CMGroupName"
}
$cmGroupId = $matchedCMGroups[0].id
Write-Information "Selected connection manager group $CMGroupName with id $cmGroupId"

$gitHubRepos | %{
  $repo = $_
  Write-Information ("Checking {0}" -f $repo.html_url)
  $isExistingNode = ($gitHubNodes | Where-Object { $_.medium_hostname -eq $repo.html_url }).count  -gt 0
  if ($isExistingNode){
    Write-Information ("{0} is already added" -f $repo.url)
  } else{

    Write-Information ("Adding {0}" -f $repo.url)
    
    $body = @{
      "node"= @{
        "connection_manager_group_id"=  $cmGroupId
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
    $guardianNodesUri = "https://$GuardianHostName/api/v2/nodes.json" 
    $jsonBody = (ConvertTo-Json $body)
    if ($PSCmdlet.ShouldProcess($jsonBody)){
      $r = Invoke-RestMethod -URI $guardianNodesUri -Headers $guardianHeaders -Body $jsonBody -Method POST -ContentType 'application/json'
    }
  }
}