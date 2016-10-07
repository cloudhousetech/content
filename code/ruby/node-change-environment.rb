require 'json'
require 'erb'

api_key            = "<< your api key"
secret_key         = "<< your secret key >>"
combined_key       = "#{api_key}#{secret_key}"
upguard_instance   = "<< your upguard instance url >>"
hostname           = `hostname`.strip
to_environment_id  = 1
node_details       = '{ "node": { "environment_id": ' + "\"#{to_environment_id}\"" + '} }'

# We need the node Id to edit the node. We can perform a lookup based on the node's hostname
lookup_resp = `curl -X GET -s -k -H 'Authorization: Token token="#{combined_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{upguard_instance}/api/v2/nodes/lookup?name=#{ERB::Util.url_encode(hostname)}`
if lookup_resp.is_a?(String) && lookup_resp.include?("node_id")
  lookup_json = JSON.load(lookup_resp)
  node_id = lookup_json['node_id']
  # Update node environment
  update_resp = `curl -X PUT -s -k -H 'Authorization: Token token="#{combined_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '#{node_details}' #{upguard_instance}/api/v2/nodes/#{node_id}`
  if update_resp.is_a?(String) && update_resp == ""
    puts "upguard: node id #{node_id} updated with environment id #{to_environment_id}"
  else
    puts "upguard: #{update_resp}"
    exit
  end
else
  puts "upguard: #{lookup_resp}"
  exit
end
