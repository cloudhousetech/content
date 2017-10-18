# This script will send a simple email (no UpGuard headings) when it picks up a policy failure
# This should be run once a day, after the policy has been run (which is after an environment scan has completed)

$secret_key = 'secret key goes here'
$api_key = 'api key goes here'
$url = 'appliance.url.here'
$policy_id = 0
$insecure = $true

# Email Settings
$smtp_server = ""
$from = ""
$to = ""
$subject = "UpGuard Policy Failed"

$headers = @{'Authorization' = 'Token token="' + $api_key + $secret_key + '"'}
$endpoint = "$($url)/api/v2/policies/$($policy_id)/latest_results.json?failed_only=true"

if ($insecure)
{
  add-type @"
  using System.Net;
  using System.Security.Cryptography.X509Certificates;
  public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
      ServicePoint srvPoint, X509Certificate certificate,
      WebRequest request, int certificateProblem) {
      return true;
    }
  }
"@
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

$req = Invoke-WebRequest $endpoint -Headers $headers -ContentType "application/json"

if ($req)
{
  if ($req.StatusCode > 400)
  {
    throw [System.Exception] $req.StatusCode.ToString() +
    " " + $req.StatusDescription
  }
  else
  {
    $json = $req.Content | ConvertFrom-Json
    Write-Output "Found $($json.policy_stats.Count) failed policies"
    if ($json.policy_stats.Count -gt 0)
    {
      $message = "The following nodes have failed:`n`n"
      foreach ($result in $json.policy_stats)
      {
        $message += "* $($result.name)`n"
      }
      # Send-MailMessage -SmtpServer $smtp_server -From $from -To $to -Body $message
      Write-Output $message
    }
  }
}
