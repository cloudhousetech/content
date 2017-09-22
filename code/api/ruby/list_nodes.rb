require 'httparty'
require 'json'
require 'optparse'

# UpGuard Support Site Documentation: https://support.upguard.com/upguard/nodes-api-v2.html#index
# Usage Instructions:
#   To use, please input the Authorization parameters below for scheme, api_key, secret_key, and URL
#   Minimum requirements: Ruby 2.0.0, httparty gem
# 
# Optional flags:
#   --disable_ssl: Disable SSL certificate verification
#   --status: filters results by node status
#   --last_scan_status: filter results by nodes' last scan status
# 
# Usage Example:
#   ./<path-to-script>/list_nodes.rb --disable_ssl --status active

# Flag Parsing
options                    = {}
options[:SSL_cert]         = true
options[:status]           = nil
options[:last_scan_status] = nil

opt_parser = OptionParser.new do |opt|
  opt.on('--disable_ssl') do
    options[:SSL_cert] = false
  end
  
  opt.on('--status=STATUS') do |s|
    options[:status] = s
  end
  
  opt.on('--last_scan_status=LASTSCANSTATUS') do |l|
    options[:last_scan_status] = l
  end
end

opt_parser.parse!

# Authorization
url        = '' # Example: https://123.0.0.1 or http://<my-server>.com
api_key    = '' # Service API key under Manage Accounts | Account
secret_key = '' # Secret key shown when API enabled in Manage Accounts | Account | Enable API access

header     = { "Authorization" => "Token token=\"#{api_key}#{secret_key}\"" }
page       = 1
per_page   = 100
response   = Array.new(per_page)
nodes      = Array.new

# Query Parameters
query = ''
query += "status=#{options[:status]}&"                     if (options[:status] != nil) 
query += "last_scan_status=#{options[:last_scan_status]}&" if (options[:last_scan_status] != nil)

# TLS 1.2
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = :TLSv1_2

# Paginate API requests
while !response.nil? and response.count == per_page
  link = "#{url}/api/v2/nodes.json?#{query}page=#{page.to_s}&per_page=#{per_page.to_s}"
  puts "Attempting to invoke #{link}"
  response = HTTParty.get(link, headers: header, :verify => options[:SSL_cert])
  
  if response.code != 200
    puts "Error, server responded with: #{response.code} - #{response["error"]}"
  else
    nodes += response
  end
  
  page += 1
end

# Print Results
puts "Retreived #{nodes.count} nodes"
puts JSON.pretty_generate(nodes)
