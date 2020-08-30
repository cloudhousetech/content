$Result = @()

$output = auditpol /list /category

$output | ForEach-Object -Process {
  $cat = $_.Trim()
  if ($cat -eq "Category/Subcategory") {
    return
  }

  $obj = New-Object psobject
  $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value $cat

  auditpol /get /category:"$cat" | Foreach-Object -Process {
    $line = $_
    if (-Not $line.StartsWith("  ")) {
      return
    }

    $tokens = $line -split "  "
    $key = ""
    $val = ""
    foreach ($token in $tokens) {
      if ($token.trim() -eq "") {
        continue
      }
      if ($key -eq "") {
          $key = $token
      } else {
          $val = $token
      }
    }

    $obj | Add-Member -MemberType NoteProperty -Name $key.ToString().Trim() -Value $val.ToString().Trim() -ErrorAction SilentlyContinue
  }
  $Result += $obj
}

$Result