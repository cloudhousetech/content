require 'puppet'
require 'json'
require 'erb'

Puppet::Reports.register_report(:upguard) do

  Puppet.notice("upguard: notice: test message")
  Puppet.info("upguard: info: test message")
  Puppet.debug("upguard: debug: test message")
  Puppet.err("upguard: err: test message")

  desc "Create a node (if not present) and kick off a node scan in UpGuard if changes were made."

  configfile = File.join([File.dirname(Puppet.settings[:config]), "upguard.yaml"])
  raise(Puppet::ParseError, "upguard.yaml config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError => e
    raise Puppet::ParserError, "upguard.yaml file is invalid"
  end

  APPLIANCE_URL = config[:appliance_url]
  SERVICE_KEY = config[:service_key]
  SECRET_KEY = config[:secret_key]
  API_KEY = "#{SERVICE_KEY}#{SECRET_KEY}"
  WINDOWS_CM_GROUP_ID = config[:windows_cm_group_id]

  def process

    Puppet.notice("upguard: notice: test message")
    Puppet.info("upguard: info: test message")
    Puppet.debug("upguard: debug: test message")
    Puppet.err("upguard: err: test message")

    self.status != nil ? status = self.status : status = 'undefined'

    if status == 'changed'
      node_ip_hostname = self.host
      manifest_filename = ERB::Util.url_encode("#{self.logs.first.file.truncate(45)}")

      lookup = node_lookup(API_KEY, APPLIANCE_URL, node_ip_hostname)

      if lookup["node_id"]
        node_id = lookup["node_id"]
      elsif lookup["error"] == "Not Found"
        node_id = node_create(API_KEY, APPLIANCE_URL, node_ip_hostname, WINDOWS_CM_GROUP_ID)
      else
        Puppet.notice("upguard: failed to lookup node: #{lookup}")
      end

      job = node_scan(API_KEY, APPLIANCE_URL, node_id, manifest_filename)

      if job["job_id"]
        Puppet.notice("upguard: node scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{job["job_id"]}/show_job?show_all=true)")
      else
        Puppet.notice("upguard: failed to kick off node scan against #{node_ip_hostname} (#{node_id}): #{job}")
      end
    end
  end

  # Check to see if the node has already been added to UpGuard. If so, return it's node_id.
  def node_lookup(api_key, instance, external_id)
    response = `curl -X GET -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/lookup.json?external_id=#{external_id}`
    JSON.load(response)
  end
  module_function :node_lookup

  # Creates a Windows 2012 node in UpGuard. TODO: Find a way to get OS details from Puppet so this isn't hardcoded.
  def node_create(api_key, instance, ip_hostname, windows_cm_group_id)
    node_details = '{ "node": { "name": ' + "\"#{ip_hostname}\"" + ', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": 1, "operating_system_id": 125, "medium_type": 7, "medium_port": 5985, "connection_manager_group_id": ' + "\"#{windows_cm_group_id}\"" + ', "medium_hostname": ' + "\"#{ip_hostname}\"" + ', "external_id": ' + "\"#{ip_hostname}\"" + '}}'
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '#{node_details}' #{instance}/api/v2/nodes`
    node = JSON.load(response)
    if node["id"]
      node["id"]
    else
      Puppet.notice("upguard: failed to create node: #{ip_hostname}")
    end
  end
  module_function :node_create

  # Kick off a node scan
  def node_scan(api_key, instance, node_id, tag)
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/#{node_id}/start_scan.json?label=#{tag}`
    JSON.load(response)
  end
  module_function :node_scan
end
