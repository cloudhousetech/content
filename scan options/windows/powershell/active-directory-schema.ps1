Import-Module ActiveDirectory

$schema = Get-ADObject -SearchBase ((Get-ADRootDSE -Server (hostname)).schemaNamingContext) -SearchScope OneLevel -Filter * -Property objectClass, name, whenChanged,` 
whenCreated | Select-Object objectClass, name, whenCreated, whenChanged, ` 
@{name="event";expression={($_.whenCreated).Date.ToShortDateString()}} | ` 
Sort-Object whenCreated

$output = '' | Select name, raw
$output.name = 'AD Schema'
$output.raw = ''
foreach($result in $schema) {
$output.raw += $result | Select objectClass, name, whenCreated, whenChanged
 $output.raw += "`r`n"
}

$output
