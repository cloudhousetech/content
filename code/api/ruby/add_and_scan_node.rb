require 'active_support/all'
require "httparty"

@website    = "https://<YOUR_SITE>.upguard.org"
@api_key    = <YOUR_API_KEY>
@secret_key = <YOUR_SECRET_KEY>
@headers    = { "Authorization" => "Token token=\"#{@api_key}#{@secret_key}\"" }

# Key Medium Types
# AGENT   = 1
# SSH     = 3
# HTTPS   = 6
# WINRM   = 7

node        = { 
                "name"                        => "My Node", 
                "medium_hostname"             => "mynode.mydomain.com",  
                "node_type"                   => "SV", 
                "medium_type"                 => 3, 
                "medium_username"             => "root", 
                "connection_manager_group_id" => 1,
                "operating_system_family_id"  => 2,            # Linux
                "operating_system_id"         => 231,          # CentOS
              }

puts "Creating #{node["name"]} node record in UpGuard..."
response = HTTParty.post(
    "#{@website}/api/v1/nodes.json",
    :headers => @headers,
    :body => node.map{|k, v| "node[#{k.to_s}]=#{v.to_s}"}.join('&')
)

if response.code == 201
  puts "  Node #{response["name"]} (id: #{response["id"]} Added to UpGuard)"
  node["ug_id"] = response["id"]
  puts "  Initiating first scan..."
  response = HTTParty.post(
      "#{@website}/api/v1/nodes/#{node["ug_id"]}/start_scan.json",
      :headers => @headers,
      :body => node.map{|k, v| "node[#{k.to_s}]=#{v.to_s}"}.join('&')
  )     
  if response.code == 201
    puts "  Scan started successfully."
  else
    puts "  Error starting scan."
  end   
else
  puts "    Failed to add node #{node["name"]}"
  puts "    ErrorCode = #{response.code}"
  puts "    ErrorBody = #{response.body}"
end
