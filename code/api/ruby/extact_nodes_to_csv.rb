require 'active_support/all'
require "httparty"

@api_key    = <INSERT_API_KEY>
@secret_key = <INSERT_SECRET_KEY>
@website    = 'https://<INSERT_SITE_DOMAIN>'
@headers    = { "Authorization" => "Token token=\"#{@api_key}#{@secret_key}\"" }
@output_file = '/tmp/node_extract.csv'

# Get environments
env_lookup  = {}
envs        = HTTParty.get("#{@website}/api/v2/environments.json", :headers => @headers)
envs.each do |env|
  env_lookup[env["id"]] = env["name"]
end

# Get Operating System Families
osf_lookup  = {}
osfs        = HTTParty.get("#{@website}/api/v2/operating_system_families.json", :headers => @headers)
osfs.each do |osf|
  osf_lookup[osf["id"]] = osf["name"]
end

# Get Operating Systems
os_lookup   = {}
oss         = HTTParty.get("#{@website}/api/v2/operating_systems.json", :headers => @headers)
oss.each do |os|
  os_lookup[os["id"]] = os["name"]
end

# Set up file headers
File.open(@output_file, 'w') { |file| file.write("ID,Name,OSF,OS,Environment,URL\n") }

# Get nodes
nodes       = HTTParty.get("#{@website}/api/v2/nodes.json?page=1&per_page=1000", :headers => @headers)

# Loop and write to file
nodes.each do |node|
  File.open(@output_file, 'a') { |file| file.write("#{node["id"]},#{node["name"]},#{osf_lookup[node["operating_system_family_id"]]},#{os_lookup[node["operating_system_id"]]},#{env_lookup[node["environment_id"]]},#{@website}/node_groups#/nodes/#{node["id"]}\n") }
end
