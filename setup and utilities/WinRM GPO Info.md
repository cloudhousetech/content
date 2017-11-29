# WinRM GPO 
_The WinRM GPO is designed to allow customers the ability to standardize WinRM settings to meet those consistent with the defaults enabled in Windows Management Foundation 5.1 (PowerShell 5.1).  This approach serves to align earlier WinRM settings with future revisions of PowerShell and to adhere to standard security practices. 

## Application
WMF prior to 4.0 will not have the proper WinRM settings enabled to allow remote connectivity, this GPO applied to hosts prior to that revision will enable PowerShell remoting functionality by attaching the proper settings to a HTTP listener. HTTPS listeners at this time require a certificate to be attached to the listner which is not a capability of the GPO settings library.  In that particular case, DSC, is the recommend approach.    

*Scoping*
_The GPO should be applied against either an Organzational Unit (OU) or a Security Group containing the assets that lack the proper WinRM settings and need to be scanned by UpGuard.

*Danger Dragons Ahead*
_The following WinRM settings or specific server types should be further scrutinized prior to applicaiton of this GPO as they have not been tested extensively for impact.
1. Hosts with legacy listeners, or hosts that have enabled compatibility for WinRM legacy listeners.
2. Any host with specialized or non-default PS listeners.
3. Exchange 2010 & 2013, Lync 2010 & 2013
4. Trusted hosts list (this GPO trusts all hosts in a domain).
5. Remote Server Management List (This GPO trusts all hosts in a domain).

## Settings
This section covers the settings applied by the GPO. 


###System Services
1. Windows Remote Management (WS-Management) - Startup Mode Automatic

### Windows Firewall with Advanced Security
1. Global Settings - None Configured
2. Inbound Rules - Windows Remote Management (HTTP-IN)
Policy                              |Value 
|:------                             |:----- 
|Enabled | True
|Program | System
|Action | Allow
|Security | Require Authentication
|Protocol | 6
|Local Port | 5985
|Remote Port | Any
|ICMP Settings | ANy
|Local Scope | Any
|Remote Scope | Any
|Profile | Domain
|Netowrk Interface Type | All
|Allow Edge traversal | false
|Group | Windows Remote Management
### Administrative Templates
1. Network/Network/Connections/Windows Firewall/Domain Profile
Policy                              |Value 
|:------                            |:----- 
|Windows Firewall: Define Inbound program exceptions  |enabled
|Define Program Exceptions |5985:TCP:*:Enabled:WinRM
2. Windows Components/Windows Remote Management (WinRM)/WinRM Client

|Policy                              |Value 
|:------                             |:----- 
|Allow basic authentication          |disabled
|Allow CredSSP authentcation         |disabled
|Allow unencrypted traffic           |disabled
|Disallow Diegest authentication     |enabled
|Disallow Kerberos authentication    |disabled
|Disallow Negotiate authentication   |disabled
|Trusted hosts                       |Enabled 
|Trust Hosts list                    |*

3. Windows Components/Windows Remoe Management (WinRM)/WinRMService

|Policy                              |Value 
|:------                             |:----- 
|Allow basic authentication          |disabled
|Allow CredSSP authentcation         |disabled
|Allow Remote Server management through WinRM | enabled
|IPv4 Filter                         | * 
|Allow unencrypted traffic           |disabled
|Disallow Kerberos authentication    |disabled
|Disallow Negotiate authentication   |disabled
|Disallow WinRM from storing RunAS Credentials | Enabled
|Specify channel binding token hardening level | Enabled
|token hardening level               |Relaxed
|Turn On Compatibality HTTP Listener                      |Disabled 
|Turn on Compatiablity HTTPS Listener                  |*
4. Windows Components/Windows Remote Shell
|Property                            |Value 
|:------                             |:----- 
|Allow Remote Shell Access           | Enabled

## File Inventory

1. WinRM PS Settings.htm - _Standard export of GPO settings_
2. Backup.xml - _backup of the gpo_
3. GPReport.xml - _listing of the GPO in xml format_
4. Winrm_V1.zip - _all the above zipped_

