require 'httparty'
require 'json'
require 'optparse'

# UpGuard Support Site Documentation: https://support.upguard.com/upguard/environments-api-v2.html
# Usage Instructions:
#   - To use, please input the Authorization parameters below for URL, api_key, and secret_key
#   - Minimum requirements: httparty gem, Ruby 2.0.0
# 
# API Flags:
#   --env_id: Lists an environment's nodes given its numeric environment ID
#   --env_name: Lists an environment's environment numeric ID given its name
#
# Optional Flags:
#   --print_json: Prints API results in JSON format
#   --debug_output: Enables script debugging output
#   --disable_ssl: Disables SSL certificate verification
#
# Usage Example(s):
#   ./<path-to-script>/list_environments.rb
#   ./<path-to-script>/list_environments.rb --env_id 4
#   ./<path-to-script>/list_environments.rb --env_name 'Duplicate Nodes'

# Flag Parsing
options               = {}
options[:SSL_cert]    = true
options[:env_id]      = nil
options[:env_name]    = nil
options[:print_json]  = false
options[:debug_output] = false 

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
  
  opt.on('--env_id=ENVIRONMENTID') do |e|
    options[:env_id] = e
  end
  
  opt.on('--env_name=ENVIRONMENTNAME') do |name|
    options[:env_name] = name
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
url          = '' # Example: https://123.0.0.1 or http://<my-server>.com
api_key      = '' # service Api key under Manage Accounts | Account 
secret_key   = '' # secret key shown when API enabled in Manage Accounts | Account | Enable API Access

header     = { "Authorization" => "Token token=\"#{api_key}#{secret_key}\"" }
page         = 1
per_page     = 100
environments = Array.new
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

if options[:env_name] != nil
  # Retrieve environment ID from environment name
  link = "#{url}/api/v2/environments/lookup.json?name=#{options[:env_name].gsub(" ", "+")}"
  response = invoke_web_request(link, header, options[:SSL_cert])
  if response != nil
    puts "Environment Name: #{options[:env_name]}"
    puts "Environment ID: #{response["environment_id"]}"
  end
else
  # Show environments or an evironment's nodes
  api_endpoint = 'environments.json'
  if options[:env_id] != nil
    api_endpoint = "environments/#{options[:env_id]}/nodes.json"
  end

  # Paginate API Requests
  while response.nil? || response.count == per_page
    link = "#{url}/api/v2/#{api_endpoint}?page=#{page.to_s}&per_page=#{per_page.to_s}"
    response = invoke_web_request(link, header, options[:SSL_cert])
    if response != nil
      environments += response
    end
    
    page += 1
  end

  # Print Results
  if options[:env_id] != nil
    write_optional_debug("Retrieved #{environments.count} nodes from environment #{options[:env_id]}")
  else 
    write_optional_debug("Retrieved #{environments.count} environments")
  end
  if options[:print_json]
    puts JSON.pretty_generate(environments)
  else
    puts environments
  end
end

