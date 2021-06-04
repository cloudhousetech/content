require 'active_support/all'
require "httparty"

@website    = "https://<YOUR_SITE>.upguard.org"
@api_key    = <YOUR_API_KEY>
@secret_key = <YOUR_SECRET_KEY>
@headers    = { "Authorization" => "Token token=\"#{@api_key}#{@secret_key}\"" }

def get_operating_system_ids
  osfs = HTTParty.get("#{@website}/api/v2/operating_system_families.json", :headers => @headers)
  oss  = HTTParty.get("#{@website}/api/v2/operating_systems.json",         :headers => @headers)

  osfs.each do |osf|
    # Get OS for family
    oss.select { |os| os["operating_system_family_id"] == osf["id"] }.each do |os|
      puts "OSF ID: #{osf["id"]}, OS ID: #{os["id"]} - #{os["description"]}"
    end
    puts ""
  end
end

get_operating_system_ids
