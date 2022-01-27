$webConfig = 'C:\Windows\System32\inetsrv\config\applicationHost.config'
$doc = (Get-Content $webConfig) -as [Xml]
$output = @()
foreach($site in $doc.configuration."system.applicationHost".sites.site) {
 $tempObj = New-Object -TypeName PSObject
 $tempObj | Add-Member -MemberType NoteProperty -Name Name -Value $site.name
 $tempObj | Add-Member -MemberType NoteProperty -Name Id -Value $site.id
 $tempObj | Add-Member -MemberType NoteProperty -Name ServerAutoStart -Value $site.serverAutoStart
 $output += $tempObj
}
$output
