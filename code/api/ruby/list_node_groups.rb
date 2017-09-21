require 'httparty'
require 'json'
require 'optparse'

=begin
UpGuard Support Site Documentation: https://support.upguard.com/upguard/node-groups-api-v2.html
To use, please input the Authorization parameters below for scheme, api_key, secret_key, and URL
Minimum requirements: Ruby 2.0.0, httparty gem
Optional flags:
  -disable_ssl: Disable SSL certificate verification
Usage Example:
  ./<path-to-script>/list_node_groups.rb -disable_ssl
=end

#Flag Parsing
options = {}
options[:SSL_cert] = true

opt_parser = OptionParser.new do |opt|
  opt.on('-disable_ssl') do
    options[:SSL_cert] = false
  end
end

opt_parser.parse!

#Authorization
scheme     = 'https' #scheme can be https or http
api_key    = '' #secret key shown when API enabled in Manage Accounts | Account | enable api access
secret_key = '' #service Api key under Manage Accounts | Account 
url        = '' #Example: 123.0.0.1

header     = {"Authorization" => "Token token=\"#{api_key}#{secret_key}\""}
page       = 1
per_page   = 100
response = Array.new(per_page)
nodeGroups = Array.new

#TLS 1.2
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = :TLSv1_2

#Paginate API requests
while !response.nil? and response.count == per_page
  link = "#{scheme}://#{url}/api/v2/node_groups.json?page=#{page.to_s}&per_page=#{per_page.to_s}"
  puts "Attempting to invoke #{link}"
  response = HTTParty.get(link, headers: header, :verify => options[:SSL_cert])
  if response.code != 200
    puts "Error, server responded with: #{response.code} - #{response["error"]}"
  else
    nodeGroups += response
  end
  
  page += 1
end

#Print Results
puts "Retreived #{nodeGroups.count} node groups"
puts JSON.pretty_generate(nodeGroups)