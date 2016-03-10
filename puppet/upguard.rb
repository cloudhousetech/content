require 'puppet'
require 'json'
require 'erb'

Puppet::Reports.register_report(:upguard) do

  Puppet.info("upguard: starting report processor")

  desc "Create a node (if not present) and kick off a node scan in UpGuard if changes were made."

  configfile = File.join([File.dirname(Puppet.settings[:config]), "upguard.yaml"])
  raise(Puppet::ParseError, "upguard.yaml config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError => e
    raise(Puppet::ParserError, "upguard.yaml file is invalid")
  end

  APPLIANCE_URL = config[:appliance_url]
  SERVICE_KEY = config[:service_key]
  SECRET_KEY = config[:secret_key]
  API_KEY = "#{SERVICE_KEY}#{SECRET_KEY}"
  WINDOWS_CM_GROUP_ID = config[:windows_cm_group_id]

  Puppet.info("upguard: APPLIANCE_URL=#{APPLIANCE_URL}")
  Puppet.info("upguard: SERVICE_KEY=#{SERVICE_KEY}")
  Puppet.info("upguard: SECRET_KEY=#{SECRET_KEY}")
  Puppet.info("upguard: API_KEY=#{API_KEY}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_ID=#{WINDOWS_CM_GROUP_ID}")

  def process

    self.status != nil ? status = self.status : status = 'undefined'

    Puppet.info("upguard: status=#{status}")

    if status == 'changed'
      node_ip_hostname = self.host
      manifest_filename = ERB::Util.url_encode("#{self.logs.first.file.truncate(45)}")

      Puppet.info("upguard: node_ip_hostname=#{node_ip_hostname}")
      Puppet.info("upguard: manifest_filename=#{manifest_filename}")

      lookup = node_lookup(API_KEY, APPLIANCE_URL, node_ip_hostname)

      if lookup["node_id"]
        node_id = lookup["node_id"]
        Puppet.info("upguard: node found: node_id=#{node_id}")
      elsif lookup["error"] == "Not Found"
        node_id = node_create(API_KEY, APPLIANCE_URL, node_ip_hostname, WINDOWS_CM_GROUP_ID)
        Puppet.info("upguard: node not found so created: node_id=#{node_id}")
      else
        Puppet.err("upguard: failed to lookup node: #{lookup}")
        raise StandardError, "upguard: unable to get a node id: confirm config variables are correct and appliance is reachable"
      end

      job = node_scan(API_KEY, APPLIANCE_URL, node_id, manifest_filename)

      if job["job_id"]
        Puppet.info("upguard: node scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{job["job_id"]}/show_job?show_all=true)")
      else
        Puppet.err("upguard: failed to kick off node scan against #{node_ip_hostname} (#{node_id}): #{job}")
      end
    end
  end

  # Check to see if the node has already been added to UpGuard. If so, return it's node_id.
  def node_lookup(api_key, instance, external_id)
    response = `curl -X GET -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/lookup.json?external_id=#{external_id}`
    Puppet.info("upguard: node_lookup response=#{response}")
    JSON.load(response)
  end
  module_function :node_lookup

  # Creates a Windows 2012 node in UpGuard. TODO: Find a way to get OS details from Puppet so this isn't hardcoded.
  def node_create(api_key, instance, ip_hostname, windows_cm_group_id)
    node_details = '{ "node": { "name": ' + "\"#{ip_hostname}\"" + ', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": 1, "operating_system_id": 125, "medium_type": 7, "medium_port": 5985, "connection_manager_group_id": ' + "\"#{windows_cm_group_id}\"" + ', "medium_hostname": ' + "\"#{ip_hostname}\"" + ', "external_id": ' + "\"#{ip_hostname}\"" + '}}'
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '#{node_details}' #{instance}/api/v2/nodes`
    Puppet.info("upguard: node_create response=#{response}")
    node = JSON.load(response)
    if node["id"]
      node["id"]
    else
      Puppet.err("upguard: failed to create node: #{ip_hostname}")
      raise StandardError, "upguard: unable to create node: confirm node parameters are correct"
    end
  end
  module_function :node_create

  # Kick off a node scan
  def node_scan(api_key, instance, node_id, tag)
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/#{node_id}/start_scan.json?label=#{tag}`
    Puppet.info("upguard: node_scan response=#{response}")
    JSON.load(response)
  end
  module_function :node_scan
end
