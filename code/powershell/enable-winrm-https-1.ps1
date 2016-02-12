$MyFQDN = "$env:computername.$env:userdnsdomain"
$CertFile = $env:userprofile + "\" + $MyFQDN

# Create a self-signed certificate and install it
$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName $MyFQDN

# Save the certificate for later export to another box
Export-Certificate -Cert $Cert -FilePath $CertFile

# Ensure that PSRemoting is enabled
Enable-PSRemoting -SkipNetworkProfileCheck -Force

# (Optional) Remove the WinRM HTTP listener
Get-ChildItem WSMan:\Localhost\listener | Where -Property Keys -eq "Transport=HTTP" | Remove-Item -Recurse

# (Optional) Disable the firewall rule for HTTP
Disable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"

# Create a HTTPS listener with our certificate thumbprint
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint –Force

# Allow inbound traffic on port 5986
New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Name "Windows Remote Management (HTTPS-In)" -Profile Any -LocalPort 5986 -Protocol TCP
