$Events = @{}
$Days = 2
$computer = $env:COMPUTERNAME

 $eventlogs = Get-EventLog System -Source Microsoft-Windows-WinLogon -After (Get-Date).AddDays(-$Days) -ComputerName $Computer
 #$eventlogs = $eventlogs | sort InstanceID,Time -Descending
If ($eventlogs)
{ 
    
    $eventlogssort = @()
    ForEach ($log in $eventlogs)
    { 
        $User = (New-Object System.Security.Principal.SecurityIdentifier $Log.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount])
        if($events.ContainsKey("$User") -eq $false) {
            $events["$User"] = New-Object Object
            $events["$User"] | Add-Member -MemberType NoteProperty -Name "User" -Value "$User"
        }

        if($log.InstanceID -eq 7001) {
            $events["$User"] | Add-Member -MemberType NoteProperty -Name "$($log.TimeWritten)" -Value "Log on"
        } elseif ($log.InstanceID -eq 7002) {
            $events["$User"] | Add-Member -MemberType NoteProperty -Name "$($log.TimeWritten)" -Value "Log 0ff"
        }
    }
}

$events.Values