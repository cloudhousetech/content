###### Variables that need to be set accordingly ######
 
$userName = 'domain.net\user'
$hostName = 'HOSTNAME'
 
###### STEP 1. The service user needs to have a session configuration defined ######
 
function Set-SessionConfig
{
    Param( [string]$userName )
    $account = New-Object Security.Principal.NTAccount $userName
    $sid = $account.Translate([Security.Principal.SecurityIdentifier]).Value
    $config = Get-PSSessionConfiguration -Name "Microsoft.PowerShell"
    $existingSDDL = $Config.SecurityDescriptorSDDL
    $isContainer = $false
    $isDS = $false
    $SecurityDescriptor = New-Object -TypeName Security.AccessControl.CommonSecurityDescriptor -ArgumentList $isContainer,$isDS, $existingSDDL
    $accessType = "Allow"
    $accessMask = 268435456
    $inheritanceFlags = "none"
    $propagationFlags = "none"
    $SecurityDescriptor.DiscretionaryAcl.AddAccess($accessType,$sid,$accessMask,$inheritanceFlags,$propagationFlags)
    $SecurityDescriptor.GetSddlForm("All")
}
 
$newSDDL = Set-SessionConfig -user $userName
Set-PSSessionConfiguration -name "Microsoft.PowerShell" -SecurityDescriptorSddl $newSDDL -force 
 
###### STEP 2. The service user needs to be added to the root/cimv2 namespace ###### 
 
function Get-SID
{
    Param (
      $DSIdentity
    )
    $ID = new-object System.Security.Principal.NTAccount($DSIdentity)
    return $ID.Translate( [System.Security.Principal.SecurityIdentifier] ).toString()
}
 
$sid = Get-SID $userName
$SDDL = "A;;CCWP;;;$sid"
$DCOMSDDL = "A;;CCDCRP;;;$sid"
$computers = $hostName
foreach ($strcomputer in $computers)
{
    $Reg = [WMIClass]"\\$strcomputer\root\default:StdRegProv"
    $DCOM = $Reg.GetBinaryValue(2147483650,"software\microsoft\ole","MachineLaunchRestriction").uValue
    $security = Get-WmiObject -ComputerName $strcomputer -Namespace root/cimv2 -Class __SystemSecurity
    $converter = new-object system.management.ManagementClass Win32_SecurityDescriptorHelper
    $binarySD = @($null)
    $result = $security.PsBase.InvokeMethod("GetSD",$binarySD)
    $outsddl = $converter.BinarySDToSDDL($binarySD[0])
    $outDCOMSDDL = $converter.BinarySDToSDDL($DCOM)
    $newSDDL = $outsddl.SDDL += "(" + $SDDL + ")"
    $newDCOMSDDL = $outDCOMSDDL.SDDL += "(" + $DCOMSDDL + ")"
    $WMIbinarySD = $converter.SDDLToBinarySD($newSDDL)
    $WMIconvertedPermissions = ,$WMIbinarySD.BinarySD
    $DCOMbinarySD = $converter.SDDLToBinarySD($newDCOMSDDL)
    $DCOMconvertedPermissions = ,$DCOMbinarySD.BinarySD
    $result = $security.PsBase.InvokeMethod("SetSD",$WMIconvertedPermissions)
    $result = $Reg.SetBinaryValue(2147483650,"software\microsoft\ole","MachineLaunchRestriction", $DCOMbinarySD.binarySD)
}
 
###### STEP 3. The service user needs to be able to query service control manager ###### 
 
$sc_param = 'D:(A;;CCLCRPRC;;;AU)(A;;CCLCRPWPRC;;;SY)(A;;KA;;;BA)S:(AU;FA;KA;;;WD)(AU;OIIOFA;GA;;;WD)'
sc.exe sdset scmanager $sc_param
 
###### Debugging Commands ######
 
#winrm quickconfig
#winrm get winrm/config
#Get-PSSessionConfiguration -Name "Microsoft.PowerShell" | Format-List
 
#$Username = 'domain.net\user'
#$Password = 'password'
#$SecurePass = ConvertTo-SecureString -AsPlainText $Password -Force
#$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $Username,$SecurePass
#Invoke-Command -ConnectionUri http://HOSTNAME:5985/wsman -ScriptBlock { gwmi Win32_OperatingSystem } -Credential $Cred
