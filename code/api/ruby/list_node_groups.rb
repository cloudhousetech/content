require 'httparty'
require 'json'
require 'optparse'

# UpGuard Support Site Documentation: https://support.upguard.com/upguard/node-groups-api-v2.html
# To use, please input the Authorization parameters below for scheme, api_key, secret_key, and URL
# Minimum requirements: Ruby 2.0.0, httparty gem
# Optional flags:
#   --disable_ssl: Disable SSL certificate verification
#   --node_group_id: lists nodes categorized under a node group ID number
# Usage Example:
#   ./<path-to-script>/list_node_groups.rb --disable_ssl
#   ./<path-to-script>/list_node_groups.rb --node_group_id 32

# Flag Parsing
options                 = {}
options[:SSL_cert]      = true
options[:node_group_id] = nil

opt_parser = OptionParser.new do |opt|
  opt.on('--disable_ssl') do
    options[:SSL_cert] = false
  end

  opt.on('--node_group_id=NODEGROUP') do |ng|
    options[:node_group_id] = ng
  end
end

opt_parser.parse!

# Authorization
url        = '' # Example: https://123.0.0.1 or http://<my-server>.com
api_key    = '' # Service API key under Manage Accounts | Account 
secret_key = '' # Secret key shown when API enabled in Manage Accounts | Account | enable API access

header       = {"Authorization" => "Token token=\"#{api_key}#{secret_key}\""}
page         = 1
per_page     = 100
node_groups   = Array.new
response     = nil

api_endpoint = 'node_groups.json'
if options[:node_group_id] != nil
  api_endpoint = "node_groups/#{options[:node_group_id]}/nodes.json"
end

# TLS 1.2
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = :TLSv1_2

# Paginate API requests
while response.nil? || response.count == per_page
  link = "#{url}/api/v2/#{api_endpoint}?page=#{page.to_s}&per_page=#{per_page.to_s}"
  puts "Attempting to invoke #{link}"
  response = HTTParty.get(link, headers: header, :verify => options[:SSL_cert])
  if response.code != 200
    puts "Error, server responded with: #{response.code} - #{response["error"]}"
  else
    node_groups += response
  end

  page += 1
end

# Print Results
if options[:node_group_id] != nil
  puts "Retrieved #{node_groups.count} nodes from node group #{options[:node_group_id]}"
else
  puts "Retreived #{node_groups.count} node groups"
end
puts JSON.pretty_generate(node_groups)