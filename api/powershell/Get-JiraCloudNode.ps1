<#
.SYNOPSIS
    Scans Jira Cloud configuration for Guardian Script Path (Windows) node type
.DESCRIPTION
  Gets application properties, advanced settings and configuration from Jira Cloud API using basic auth and returns it as JSON compatible for use in Guardian's Script Path (Windows) node type
.PARAMETER JiraHostname
  Host name of Jira cloud you want to connect to. e.g. 'company.atlassian.net'
.PARAMETER Username
  Your Jira username
.PARAMETER ApiToken
  Your personal Jira ApiToken
.EXAMPLE
  .\Get-JiraCloudNode.ps1 -JiraHostName 'company.atlassian.net' -Username you@company.com -ApiToken {{password}}

  Using this as the script path in Guardian node configuration will scan your Jira configuration
#>

param (
  [Parameter(Mandatory = $true)]
  [string]$JiraHostname,
  [Parameter(Mandatory = $true)]
  [string]$Username,
  [Parameter(Mandatory = $true)]
  [string]$ApiToken
)

Set-Variable JiraRestUri -Option Constant -Value ("https://$JiraHostname" + '/rest/api/3/')
$headers = @{Authorization = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${Username}:${ApiToken}")))" }

$applicationProperties = Invoke-RestMethod ($JiraRestUri + 'application-properties') -Headers $headers
$advancedSettings = Invoke-RestMethod ($JiraRestUri + 'application-properties/advanced-settings') -Headers $headers
$configuration = Invoke-RestMethod ($JiraRestUri + 'configuration') -Headers $headers

# convert property array into hash
$appPropertyHash = @{}
$applicationProperties | ForEach-Object {
  $property = $_
  $appPropertyHash[($property.key)] = $property
}

$advancedSettingsHash = @{}
$advancedSettings | ForEach-Object {
  $setting = $_
  $advancedSettingsHash[($setting.key)] = $setting
}


ConvertTo-Json @{'Application Properties' = $appPropertyHash
  'Advanced Settings'                     = $advancedSettingsHash
  'Configuration'                         = @{'Configuration' = $configuration}
}

