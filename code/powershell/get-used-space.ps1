$freespace = Get-WmiObject -Class Win32_logicalDisk | ? {$_.DriveType -eq '3'}
$drive = ($FreeSpace.DeviceID).Split("=")
$temp = '' | Select FreeSpace, Drive
$temp.FreeSpace = $freespace.Size - $freespace.FreeSpace
$temp.Drive = $drive[0]
$temp
