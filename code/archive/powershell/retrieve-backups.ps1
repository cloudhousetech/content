# Author: UpGuard
# Email: support@upguard.com
# Description: BitsTransfer for downloading very large files without using an excessive amount of system memory.

Import-Module BitsTransfer

$username = "<< backup username >>"
$password = "<< backup password >>"
$password_secure = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ($username, $password_secure)
$backup_endpoint = "https://<< your.appliance.hostname >>/backups/latest.tar.gz"
$backup_location = "C:\Backups\"
$backup_file = Get-Date -Format yyyy-MM-ddTHH-mm-ss
$backup_filepath = $backup_location + $backup_file + ".tar.gz"

# We make a unique display name for the transfer so that it can be uniquely
# referenced by name and will not return an array of jobs if we have run the
# script multiple times simultaneously.
$display_name = "MyBitsTransfer " + (Get-Date)

Start-BitsTransfer `
    -Source $backup_endpoint `
    -Destination $backup_filepath `
    -DisplayName $display_name `
    -Authentication Basic `
    -Credential $credentials `
    -Asynchronous

# Enable CRL Check, Ignore invalid common name in server certificate, Ignore invalid date in  server certificate
# & "bitsadmin" /SetSecurityFlags $display_name 7

$job = Get-BitsTransfer $display_name

# Create a holding pattern while we wait for the connection to be established
# and the transfer to actually begin.  Otherwise the next Do...While loop may
# exit before the transfer even starts.  Print the job status as it changes
# from Queued to Connecting to Transferring.
# If the download fails, remove the bad job and exit the loop.
$lastStatus = $job.JobState
Do {
    If ($lastStatus -ne $job.JobState) {
        $lastStatus = $job.JobState
        $job
    }
    If ($lastStatus -like "*Error*") {
        Write-Host "Error connecting to download."
        Write-Host $job.ErrorDescription
        Get-BitsTransfer | Complete-BitsTransfer
        Exit
    }
}
while ($lastStatus -ne "Transferred" -and $lastStatus -ne "Transferring")
$job

# Print the transfer status as we go:
#   Date & Time   BytesTransferred   BytesTotal   PercentComplete
do {
    Write-Host (Get-Date) $job.BytesTransferred $job.BytesTotal `
        ($job.BytesTransferred/$job.BytesTotal*100)
    Start-Sleep -s 10
}
while ($job.BytesTransferred -lt $job.BytesTotal)

# Print the final status once complete.
Write-Host (Get-Date) $job.BytesTransferred $job.BytesTotal `
    ($job.BytesTransferred/$job.BytesTotal*100)

Complete-BitsTransfer $job

# Only keep the last two backups. There is no need to store backups beyond this.
# We sort by Name because it includes a DateTime stamp.
$backup_files = Get-ChildItem $backup_location -Filter *.tar.gz | Sort Name -Descending
if ($backup_files.count -gt 2) {
    Remove-Item $backup_files[-1].FullName
}

#Get-BitsTransfer
#Get-BitsTransfer | Complete-BitsTransfer
#net stop BITS
#net start BITS
