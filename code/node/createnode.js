'use strict';

var https = require('https');
var prettyjson = require('prettyjson');

var api_key = process.env.apikey; // Define these as environment variables with "export apikey='XXXXXXXXXXXXXXX'"
var secret_key = process.env.secretkey; // Or define them in here: secret_key =
var api_base_url = process.env.apiurl;

var options = {
  host: api_base_url,
  port: 443,
  method: 'POST',
  path: '/api/v2/nodes.json',
  // Authentication Headers:
  headers: {
    'Authorization': 'Token token="'+ api_key + secret_key + '"',
    'Content-Type': 'application/json'
  }
};

var nodejson = {
  name: 'TestingAPINode',
  node_type: 'SV'
};

var postable = { node: nodejson };

console.log(postable);

var postreq = https.request(options, function(res){

  var body = "";

  res.on('data', function(chunk) {
    body += chunk;
    console.log('Response: ' + body)
  });

  res.on('end', function() {
    //here we have the full response, html or json object
    //console.log(body);
      var jsonObject = JSON.parse(body);
      console.log(prettyjson.render(jsonObject));
    });

    res.on('error', function(e) {
      console.log("Got error: " + e.message);
   });
});

//Post the data
console.log("Creating a new node named: " + nodejson.name);
postreq.write(JSON.stringify(postable));
postreq.end();