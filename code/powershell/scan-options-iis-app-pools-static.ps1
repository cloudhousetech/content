$webConfig = 'C:\Windows\System32\inetsrv\config\applicationHost.config'
$doc = (Get-Content $webConfig) -as [Xml]
$output = @()
foreach($ap in $doc.configuration."system.applicationHost".applicationPools.add) {
 $tempObj = New-Object -TypeName PSObject
 $tempObj | Add-Member -MemberType NoteProperty -Name Name -Value $ap.name
 $tempObj | Add-Member -MemberType NoteProperty -Name ManagedRuntimeVersion -Value $ap.managedRuntimeVersion
 $tempObj | Add-Member -MemberType NoteProperty -Name ManagedPipelineMode -Value $ap.managedPipelineMode
 $tempObj | Add-Member -MemberType NoteProperty -Name AutoStart -Value $ap.autoStart
 $output += $tempObj
}
$output
