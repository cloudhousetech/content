require 'httparty'
require 'json'
require 'optparse'

# UpGuard Support Site Documentation: https://support.upguard.com/upguard/node-groups-api-v2.html
# Usage Instructions:
#   - To use, please input the Authorization parameters below for URL, api_key, and secret_key
#   - Minimum requirements: httparty gem, Ruby 2.0.0
#
# Optional Flags:
#   --disable_ssl: Disable SSL certificate verification
#   --node_group_id: lists nodes categorized under a node group ID number
#
# Usage Example(s):
#   ./<path-to-script>/list_node_groups.rb --disable_ssl
#   ./<path-to-script>/list_node_groups.rb --node_group_id 32

# Flag Parsing
options            = {}
options[:SSL_cert] = true
options[:node_id]  = nil
options[:lablel]   = nil

opt_parser = OptionParser.new do |opt|
  opt.on('--disable_ssl') do
    options[:SSL_cert] = false
  end

  opt.on('--node_id=NODEID') do |id|
    options[:node_id] = id
  end

  opt.on('--label=LABEL') do |l|
    options[:label] = label
  end
end

opt_parser.parse!

if options[:node_id] == nil
  puts "Please provide a node ID with the flag --node_id"
  abort
end

puts "node id is: #{options[:node_id]}"
puts "label is: #{options[:label]}"

# Authorization
url        = '' # Example: https://123.0.0.1 or http://<my-server>.com
api_key    = '' # Service API key under Manage Accounts | Account 
secret_key = '' # Secret key shown when API enabled in Manage Accounts | Account | Enable API Access
url = 'http://192.168.88.1:3000' #Example: 123.0.0.1:3000

header       = { "Authorization" => "Token token=\"#{api_key}#{secret_key}\"" }
label = ""

if options[:label] != nil
  lable = "?label=#{options[:label]}"
end

# TLS 1.2
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = :TLSv1_2

# Start Scan
link = "#{url}/api/v2/nodes/#{options[:node_id]}/start_scan.json#{label}"
puts "Attempting to invoke #{link}"
response = HTTParty.get(link, headers: header, :verify => options[:SSL_cert])
if response.code != 201
  puts "Error, server responded with: #{response.code} - #{response["error"]}"
else
  puts "Job ID of new scan: #{response["job_id"]}"
end