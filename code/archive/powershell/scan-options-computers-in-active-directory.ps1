$strFilter = '(objectClass=User)'
$objDomain = New-Object System.DirectoryServices.DirectoryEntry 'LDAP://DC=your,DC=ou,DC=here'
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = $objDomain
$objSearcher.PageSize = 1000
$objSearcher.Filter = $strFilter
$objSearcher.SearchScope = 'Subtree'
$colProplist = 'dnshostname','name','operatingsystem'
foreach ($i in $colPropList) {
    $objSearcher.PropertiesToLoad.Add($i)
}
$colResults = $objSearcher.FindAll()
$finalResults = @()
foreach ($objResult in $colResults) {
    foreach($prop in $objResult.Properties) {
        $obj = New-Object -TypeName PSObject
        foreach($col in $colProplist) {
            $obj | Add-Member -MemberType NoteProperty -Name $col -Value $prop[$col]
        }
    }
}
$finalResults