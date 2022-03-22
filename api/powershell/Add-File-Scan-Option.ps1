param (
    [string]$URL = $env:GUARDIAN_URL,
    [string]$ApiKey = $env:GUARDIAN_API_KEY,
    [string]$SecretKey = $env:GUARDIAN_SECRET_KEY,
    [string]$NodeGroup,
    [string]$ScanOption,
    [switch]$Insecure = $(if ($env:GUARDIAN_INSECURE -eq "true") { $true } else { $false })
)
$Headers = @{'Authorization' = "Token token=""$($ApiKey)$($SecretKey)"""; 'Accept' = 'application/json'; 'Content-Type' = 'application/json'}

# Get the ID for the node group
$GroupID = (Invoke-WebRequest -Headers $Headers -Method "GET" -Uri "$($URL)/api/v2/node_groups/lookup.json?name=$($NodeGroup)" -SkipCertificateCheck:$Insecure|ConvertFrom-Json).node_group_id
if (-not $GroupID) { Write-Output "Couldn't find node group '$($NodeGroup)'";return }
Write-Output "$($NodeGroup) has ID $($GroupID)"

# Get the current scan options for the node group
$FileScanOptions = (Invoke-WebRequest -Headers $Headers -Method "GET" -Uri "$($URL)/api/v2/node_groups/$($GroupID)/node_group_configuration.json" -SkipCertificateCheck:$Insecure|ConvertFrom-Json).scan_options.scan_directory_options
if ($FileScanOptions -eq $null) { $FileScanOptions = @() }

if ($ScanOption -eq "") { Write-Output "Existing file scan options: $($FileScanOptions)"; return }

# Add the new scan option to the file scan options
$Exists = $false
ForEach ($o in $FileScanOptions) { if ($o.path -eq $ScanOption) { $Exists = $true } }
if (-not $Exists)
{
  # Add the scan option
  Write-Output "Adding file scan option: $($ScanOption)"
  $FileScanOptions += @{ path = $ScanOption }
  $Body = @{ option_name = "scan_directory_options" ; scan_directory_options = $FileScanOptions }
  Write-Output (Invoke-WebRequest -Method "PUT" -Headers $Headers -Uri "$($URL)/api/v2/node_groups/$($GroupID)/set_scan_options.json" -Body (ConvertTo-Json $Body) -SkipCertificateCheck:$Insecure).Content
} else { Write-Output "File scan option already exists: $($ScanOption)" }

Write-Output "Done!"
