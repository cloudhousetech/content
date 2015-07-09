$ComAdmin = New-Object -com COMAdmin.COMAdminCatalog
$oapplications = $ComAdmin.getcollection('Applications')
[HashTable[]]$collected = @()
$baseDetails = @('ID', 'Name', 'AppPartitionID', 'State')
$additionalDetails = @('RecycleMemoryLimit', 'AuthenticationCapability')
$allDetails = $baseDetails + $additionalDetails
$longestFieldLength = 0

if ($oapplications) {
  $oapplications.populate()
  
  foreach ($oapplication in $oapplications){
    $obj = @{}
    $skeyappli = $oapplication.key
    $oappliInstances = $oapplications.getcollection('ApplicationInstances',$skeyappli)
    $oappliInstances.populate()

    If ($oappliInstances.count -eq 0) {
      $obj['State'] = 'Stopped'
    } Else{
      $obj['State'] = 'Running'
    }

    foreach($prop in $allDetails) {
        #"Prop: " + $prop
        try {
          # state must be included in details for output, but it is not a property per se
          if ($prop -ne 'Password' -and $prop -ne 'State') {
            # if there are multiple things with the same name, the last value will be reported
            $obj[$prop] = $oapplication.Value($prop)

            if($obj[$prop].ToString().Length -gt $longestFieldLength) {
                $longestFieldLength = $obj[$prop].ToString().Length
            }
          }

        } catch {
            "Exception encountered: " + $_.Exception.Message
        }
    }

    $collected += $obj
  }
}

$collected = $collected | Sort-Object { $_['Name'] }
$com_plus = ''

# need the extra space for padding between columns
foreach($deet in $allDetails) {
    $com_plus += $deet + (' ' * ($longestFieldLength - $deet.Length)) + ' '
}

$com_plus += "`r`n"

$com_plus += ('-' * ($com_plus.Length - 2)) + "`r`n"

foreach($o in $collected) {
    foreach($key in $allDetails) {
        if($key -ne "Password") {
            $com_plus += $o[$key].ToString() + (' ' * ($longestFieldLength - $o[$key].ToString().Length)) + ' '
        }
    }
    $com_plus += "`r`n"
}

$output = "" | Select folder, raw
$output.folder = $folder
$output.raw    = $com_plus
$output
