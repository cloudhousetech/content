$username = "<< backup username >>"
$password = "<< backup password >>"
$password_secure = ConvertTo-SecureString -AsPlainText $password -Force
$credentials = New-Object System.Management.Automation.PSCredential($username, $password_secure)
$backup_endpoint = "https://<< your.upguard.hostname >>/backups/latest.tar.gz"
$backup_location = "C:\Backups\"
$backup_file = Get-Date -Format yyyy-MM-ddTHH-mm-ss
$backup_filepath = $backup_location + $backup_file + ".tar.gz"

# Download the latest appliance backup.
Invoke-WebRequest -Uri $backup_endpoint -OutFile $backup_filepath -Credential $credentials

# Only keep the last two backups. There is no need to store backups beyond this.
$backup_files = Get-ChildItem $backup_location -Filter *.tar.gz | Sort LastWriteTime -Descending #| where {$_.extension -eq ".tar.gz"}
if ($backup_files.count -gt 2) {
    Remove-Item $backup_files[-1].FullName
}
