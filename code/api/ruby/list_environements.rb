require 'httparty'
require 'json'
require 'optparse'

# UpGuard Support Site Documentation: https://support.upguard.com/upguard/environments-api-v2.html
# Usage Instructions:
#   - Input the Authorization parameters below for URL, api_key, and secret_key
#   - Provide an API flag at execution time
#   - Minimum requirements: httparty gem, Ruby 2.0.0
# 
# API Flags:
#   --env_id: Lists an environment's nodes given it's numeric environment ID
#   --env_name: Lists an environment's environment ID given it's name
#
# Optional Flags:
#   --disable-ssl: Disables SSL certificate verification
#
# Usage Example(s):
#   ./<path-to-script>/list_environments.rb --disable_ssl --env_id 4
#   ./<path-to-script>/list_environments.rb --env_name 'Duplicate Nodes'

# Flag Parsing
options            = {}
options[:SSL_cert] = true
options[:env_id]   = nil
options[:env_name] = nil

opt_parser = OptionParser.new do |opt|
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

# Authorization
url          = '' # Example: https://123.0.0.1 or http://<my-server>.com
api_key      = '' # service Api key under Manage Accounts | Account 
secret_key   = '' # secret key shown when API enabled in Manage Accounts | Account | Enable API Access

header       = {"Authorization" => "Token token=\"#{api_key}#{secret_key}\""}
page         = 1
per_page     = 100
environments = Array.new
response     = nil

api_endpoint = 'environments.json'
if options[:env_id] != nil
  api_endpoint = "environments/#{options[:env_id]}/nodes.json"
end

# TLS 1.2
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ssl_version] = :TLSv1_2

if options[:env_name] != nil
  # Retrieve environment ID from environment name
  link = "#{url}/api/v2/environments/lookup.json?name=#{options[:env_name].gsub(" ", "+")}"
  puts "Attempting to invoke #{link}"
  response = HTTParty.get(link, headers: header, :verify => options[:SSL_cert])
  if response.code != 200
    puts "Error, server responded with: #{response.code} - #{response["error"]}"
  else
    puts "Environment Name: #{options[:env_name]}"
    puts "Environment ID: #{response["environment_id"]}"
  end
else
  # Paginate API Requests
  while response.nil? || response.count == per_page
    link = "#{url}/api/v2/#{api_endpoint}?page=#{page.to_s}&per_page=#{per_page.to_s}"
    puts "Attempting to invoke #{link}"
    response = HTTParty.get(link, headers: header, :verify => options[:SSL_cert])
    if response.code != 200
      puts "Error, server responded with: #{response.code} - #{response["error"]}"
    else
      environments += response
    end
    
    page += 1
  end

  # Print Results
  if options[:env_id] != nil
    puts "Retreived #{environments.count} nodes from environment #{options[:env_id]}" 
  else 
    puts "Retreived #{environments.count} environments"
  end
  puts JSON.pretty_generate(environments)
end

