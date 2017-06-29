$username = "<< backup username >>"
$password = "<< backup password >>"
$password_secure = ConvertTo-SecureString -AsPlainText $password -Force
$credentials = New-Object System.Management.Automation.PSCredential($username, $password_secure)
$backup_endpoint = "https://<< your.upguard.hostname >>/backups/latest.tar.gz"
$backup_location = "C:\Backups\"
$backup_file = Get-Date -Format yyyy-MM-ddTHH-mm-ss
$backup_filepath = $backup_location + $backup_file + ".tar.gz"

# Download the latest appliance backup. WebClient is used here so that streaming is buffered to disk rather than to memory.
$webclient = New-Object System.Net.WebClient
$Webclient.Credentials = New-Object System.Net.Networkcredential($username, $password)
$webclient.DownloadFile($backup_endpoint, $backup_filepath)

# Only keep the last two backups. There is no need to store backups beyond this.
$backup_files = Get-ChildItem $backup_location -Filter *.tar.gz | Sort LastWriteTime -Descending
if ($backup_files.count -gt 2) {
    Remove-Item $backup_files[-1].FullName
}
