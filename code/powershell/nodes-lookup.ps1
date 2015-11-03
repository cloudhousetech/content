

NEEDS TO BE CHANGED BEFORE ADDING TO DOCS SITE


$headers = @{'Authorization' = 'Token token="AB123456CDEF7890GH"';
             'Accept' = 'application/json'}

$req = Invoke-WebRequest
    "http://localhost:3000/api/v1/nodes/42/add_to_node_group.json?node_group_id=23"
    -Method "Post" -Headers $headers

if ($req.StatusCode > 400)
{
  throw [System.Exception] $req.StatusCode.ToString() +
    " " + $req.StatusDescription
}
else
{
    $req.Content | ConvertFrom-Json
}