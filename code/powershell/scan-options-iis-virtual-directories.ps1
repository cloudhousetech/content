$webConfig = 'C:\Windows\System32\inetsrv\config\applicationHost.config'
$doc = (Get-Content $webConfig) -as [Xml]
$output = @()
foreach($site in $doc.configuration."system.applicationHost".sites.site) {
   foreach($vdir in $site.application.virtualDirectory) {
     $tempObj = New-Object -TypeName PSObject
     $tempObj | Add-Member -MemberType NoteProperty -Name Name -Value "$($site.name): $($vdir.path)"
     $tempObj | Add-Member -MemberType NoteProperty -Name PhysicalPath -Value $vdir.physicalPath
     $output += $tempObj     
   }
}
$output
