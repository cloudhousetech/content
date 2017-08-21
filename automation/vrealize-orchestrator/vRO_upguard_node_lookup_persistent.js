//prepare request
//Do not edit
var inParamtersValues = [nodeName];
var request = restOperation.createRequest(inParamtersValues, null);
//set the request content type
request.contentType = "";
System.log("Request: " + request);
System.log("Request URL: " + request.fullUrl);

//Customize the request here
//request.setHeader("headerName", "headerValue");
request.setHeader('Authorization', 'Token token="{apikey+secretkey}"')


//execute request
//Do not edit
var response = request.execute();
//prepare output parameters
System.log("Response: " + response);
statusCode = response.statusCode;
statusCodeAttribute = statusCode;
System.log("Status code: " + statusCode);
contentLength = response.contentLength;
headers = response.getAllHeaders();
contentAsString = response.contentAsString;
System.log("Content as string: " + contentAsString);

var node = JSON.parse(contentAsString);
nodeId = node.node_id.toString();
System.log("NodeId: " + nodeId);
