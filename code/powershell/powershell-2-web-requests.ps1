$apiKey = "YOUR_API_KEY_HERE"
$secretKey = " YOUR_SECRET_KEY_HERE "
$token = $apiKey + $secretKey
$headerPart1 = 'Authorization'
$headerPart2 = 'Token token="' + $token + '"'
$uri = "https://YOUR_GUARDRAIL/api/v1/node_groups/GROUP_NUMBER/nodes.json"
$version = $PSVersionTable.PSVersion.Major
 
# PowerShell 2.0 way
$request = [System.Net.HTTPWebRequest]::Create($uri)
$request.Method="Get"
$request.ContentType = "application/json"
$request.Headers.Set($headerPart1, $headerPart2)
 
$requestStream = $request.GetResponse().GetResponseStream()
$readStream = New-Object System.IO.StreamReader $requestStream
$data = $readStream.ReadToEnd()
$readStream.Dispose();
$readStream.Close();
 
# The loading of this dll assumes that even though you are on PowerShell 2.0 you have .NET 3.5 installed
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
$serialization = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$results = $serialization.DeserializeObject($data)
 
# Raw results
$results
