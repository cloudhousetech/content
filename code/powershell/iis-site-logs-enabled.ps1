Import-Module WebAdministration

$output = @()
foreach ($site in Get-ChildItem IIS:\Sites) {
  $obj = New-Object -TypeName PSObject
  $obj | Add-Member -MemberType NoteProperty -Name Name -Value $site.name
  $sitePath = "IIS:\Sites\" + $site.name
  $logsEnabled = (GI $sitePath).logfile.enabled
  $obj | Add-Member -MemberType NoteProperty -Name LogsEnabled -Value $logsEnabled
  $output += $obj
}
$output

