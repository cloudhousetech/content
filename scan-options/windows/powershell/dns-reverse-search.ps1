try {
    $dnsObj = @()
    $dns_results = (gwmi -query "select * from win32_networkadapterconfiguration where ipenabled = true").dnsserversearchorder
    $dns_results_count = 0
    foreach ($dns_value in $dns_results) {
        $tempObj = New-Object -TypeName PSObject
        $dns_results_count += 1
        $dns_key = "dnsReverseSearchEntry" + $dns_results_count
        $tempObj | Add-Member -MemberType NoteProperty –Name $dns_key –Value $dns_value
        $tempObj | Add-Member -MemberType NoteProperty –Name "ReverseDNS" –Value "DNS Reverse Search Entry $dns_results_count"
        $dnsObj += $tempObj
    }
    $dnsObj
} catch {
    "Exception encountered: " + $_.Exception.Message
}
