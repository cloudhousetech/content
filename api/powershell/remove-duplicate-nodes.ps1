param (
    [string]$api_key = 'api-key-here',
    [string]$secret_key = 'secret-key-here',
    [string]$url = 'https://my.upguard.url',
    [switch]$insecure = $false
)

# Perform an API request and return the result as a Powershell object
function UpGuard-WebRequest
{
    param
    (
        [string]$method = 'Get',
        [string]$endpoint,
        [hashtable]$body = @{}
    )
    # Handle very large JSON responses (such as scan data)
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    $jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
    $jsonserial.MaxJsonLength  = 67108864

    $headers = @{'Authorization' = 'Token token="' + $($api_key) + $($secret_key) + '"'}
    $req = $null
    if ($method -in "Get","Delete"){$req = Invoke-WebRequest -Method $method -Uri $endpoint -Headers $headers -ContentType "application/json"}
    else{$req = Invoke-WebRequest -Method $method -Uri $endpoint -Headers $headers -Body ($body | ConvertTo-Json) -ContentType "application/json"}
    if ($req)
    {
        if ($req.StatusCode > 400){throw [System.Exception] "$($req.StatusCode.ToString()) $($req.StatusDescription)"}
        else{return $jsonserial.DeserializeObject($req.Content)}
    }
}

# Ignore SSL certificate if `-ignore` is used
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
