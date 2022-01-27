<#
.SYNOPSIS
    Scans LastPass for Guardian Script Path (Windows) node type

.DESCRIPTION
    Uses LastPass enterprise API to return user and shared folder information for display in Guardian

.PARAMETER Cid
    Your lastpass company id - available from admin dashboard

.PARAMETER ProvHash
    You provisioning hash from LastPass UI

.EXAMPLE
    .\Get-LastPassNode.ps1 -cid yourcid -ProvHash {{password}}

    Using this as your script path in node configuration will scan LastPass user and shared folder data and present it as a Guardian node
#>

param (
  [Parameter(Mandatory = $true)]
  [string]$cid,
  [Parameter(Mandatory = $true)]
  [string]$provHash
)

$body = @{
    cid = $cid
    provhash  = $provHash
    cmd       = 'getuserdata'
    apiuser = 'guardian'
}



$response = Invoke-RestMethod 'https://lastpass.com/enterpriseapi.php' -Method POST -Body (ConvertTo-json $body)

$users = @{}
$response.Users | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach-Object {
    $id = $_
    $user = $response.Users.$id
    $users.($user.Username) = $user
}

$results = @{Users=$users}

$body.cmd = 'getsfdata'

$response = Invoke-RestMethod 'https://lastpass.com/enterpriseapi.php' -Method 'POST' -Body (ConvertTo-json $body)

$sharedFolders = @{}
$response | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach-Object {
    $id = $_
    $sf = $response.$id
    if ($sf.deleted -eq $true) {return}
    $sf | Add-Member -MemberType NoteProperty -Name 'Admins' -Value ($sf.users | Where-Object { $_.can_administer -eq 1} | Select-Object -ExpandProperty username)
    $sf | Add-Member -MemberType NoteProperty -Name 'Readonly' -Value ($sf.users | Where-Object { $_.readonly -eq 1} | Select-Object -ExpandProperty username)
    $sf | Add-Member -MemberType NoteProperty -Name 'Hide Password' -Value ($sf.users | Where-Object { $_.give -eq 0} | Select-Object -ExpandProperty username)
    $sf.Users = $sf.users | Select-Object -ExpandProperty username
    $sharedFolders.($sf.sharedfoldername) = $sf
}

$results['Shared Folders'] = $sharedFolders

ConvertTo-Json -Depth 4 $results