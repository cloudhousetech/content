require 'httparty'
require 'json'
require 'optparse'

# UpGuard Support Site Documentation: https://support.upguard.com/upguard/node-groups-api-v2.html
# Usage Instructions:
#   - To use, please input the Authorization parameters below for URL, api_key, and secret_key
#   - Minimum requirements: httparty gem, Ruby 2.0.0
#
# API Flag(s):
#   --node_group_name: Lists a node group's numeric ID given a node group name
#
# Optional Flag(s):
#   --print_json: Prints API results in JSON format
#   --debug_output: Enables script debugging output
#   --disable_ssl: Disable SSL certificate verification
#
# Usage Example(s):
#   ./<path-to-script>/list_node_groups.rb
#   ./<path-to-script>/list_node_groups.rb --node_group_id 32

# Flag Parsing
options                   = {}
options[:SSL_cert]        = true
options[:node_group_id]   = nil
options[:print_json]      = false
options[:debug_output]    = false 
options[:node_group_name] = nil

opt_parser = OptionParser.new do |opt|
  opt.on('--print_json') do
    options[:print_json] = true
  end
  
  opt.on('--debug_output') do
    options[:debug_output] = true
  end
  
  opt.on('--disable_ssl') do
    options[:SSL_cert] = false
  end
  
  opt.on('--node_group_name=NODEGROUPNAME') do |ngn|
    options[:node_group_name] = ngn
  end
end

opt_parser.parse!

# Optional Debug
$debug = options[:debug_output]
def write_optional_debug (str="")
  if $debug
    puts str
  end
end

# Authorization
url        = '' # Example: https://123.0.0.1 or http://<my-server>.com
api_key    = '' # Service API key under Manage Accounts | Account 
secret_key = '' # Secret key shown when API enabled in Manage Accounts | Account | Enable API Access

header     = { "Authorization" => "Token token=\"#{api_key}#{secret_key}\"" }
page         = 1
per_page     = 100
node_groups   = Array.new
response     = nil


# TLS 1.2
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = :TLSv1_2

def invoke_web_request(link, header, ssl)
  write_optional_debug("Attempting to invoke #{link}")
  response = HTTParty.get(link, headers: header, :verify => ssl)
  if response.code != 200
    write_optional_debug("Error, server responded with: #{response.code} - #{response["error"]}")
    nil
  else
    response
  end
end

if options[:node_group_name] != nil
  # Retrieve node group ID from a node group name
  link = "#{url}/api/v2/node_groups/lookup.json?name=#{options[:node_group_name]}"
  response = invoke_web_request(link, header, options[:SSL_cert])
  if response != nil
    puts "Node Group Name: #{options[:node_group_name]}"
    puts "Node Group ID: #{response['node_group_id']}"
  end
else
  # Show node groups or a node group's nodes
  api_endpoint = ''
  if options[:node_group_id] != nil
    api_endpoint = "node_groups/#{options[:node_group_id]}/nodes.json"
  end

  # Paginate API requests
  while response.nil? || response.count == per_page
    link = "#{url}/api/v2/node_groups.json?page=#{page.to_s}&per_page=#{per_page.to_s}"
    response = invoke_web_request(link, header, options[:SSL_cert])
    if response != nil
      node_groups += response
    end
  
    page += 1
  end
end

# Print Results
if options[:node_group_id] != nil
  write_optional_debug("Retrieved #{node_groups.count} nodes from node group #{options[:node_group_id]}")
else
  write_optional_debug("Retrieved #{node_groups.count} node groups")
end

if options[:print_json]
  puts JSON.pretty_generate(node_groups)
else
  puts node_groups
end
