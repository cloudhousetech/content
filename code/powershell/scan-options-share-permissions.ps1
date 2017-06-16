$all_shares = Get-WmiObject win32_LogicalShareSecuritySetting
$shares = @()
if($all_shares){
    foreach($s in $all_shares){
        $obj = New-Object –TypeName PSObject
        $obj | Add-Member -MemberType NoteProperty –Name Name –Value $s.name
        $ACLS = $s.GetSecurityDescriptor().Descriptor.DACL
        $permissions = @{}
        foreach($ACL in $ACLS){
            $User = $ACL.Trustee.Name
            if(!($user)){$user = $ACL.Trustee.SID}
            $Domain = $ACL.Trustee.Domain
            switch($ACL.AccessMask)
            {
                2032127 {$Perm = "Full Control"}
                1245631 {$Perm = "Change"}
                1179817 {$Perm = "Read"}
            }
            # Write-Host "$($s.Name)   $Domain\$user  $Perm"
            if($Domain){
                $permissions.Add("$($Domain)\\$($user)", $Perm)
            }else{
                $permissions.Add($user, $Perm)
            }
        }
        $obj | Add-Member -MemberType NoteProperty -Name Permissions -Value $permissions
        $shares += $obj
    }
}
$shares
