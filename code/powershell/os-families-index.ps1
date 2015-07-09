$headers = @{'Authorization' = 'Token token="AB123456CDEF7890GH"';
                 'Accept' = 'application/json'}

$req = Invoke-WebRequest
    "http://localhost:3000/api/v1/operating_system_families.json" `
    -Headers $headers

if ($req.StatusCode > 400)
{
  throw [System.Exception] $req.StatusCode.ToString() +
    " " + $req.StatusDescription
}
else
{
    $req.Content | ConvertFrom-Json
}
