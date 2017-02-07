require 'puppet'
require 'json'
require 'erb'

Puppet::Reports.register_report(:upguard) do

  VERSION = "v1.3.0"
  VERSION_TAG = "Added by #{File.basename(__FILE__)} #{VERSION}"
  desc "Create a node (if not present) and kick off a node scan in UpGuard if changes were made."

  configfile = File.join([File.dirname(Puppet.settings[:config]), "upguard.yaml"])
  raise(Puppet::ParseError, "upguard.yaml config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError => e
    raise(Puppet::ParserError, "upguard.yaml file is invalid")
  end

  APPLIANCE_URL      = config[:appliance_url]
  PUPPETDB_URL       = config[:puppetdb_url]
  COMPILE_MASTER_PEM = config[:compile_master_pem]
  SERVICE_KEY        = config[:service_key]
  SECRET_KEY         = config[:secret_key]
  API_KEY            = "#{SERVICE_KEY}#{SECRET_KEY}"
  SSH_USERNAME       = config[:ssh_username]
  SSH_PASSWORD       = config[:ssh_password]
  WINRM_USERNAME     = config[:winrm_username]
  WINRM_PASSWORD     = config[:winrm_password]
  WINDOWS_CMGS       = config[:windows_connection_manager_groups]
  SSH_CMGS           = config[:ssh_connection_manager_groups]

  def process
    Puppet.info("upguard: starting report processor #{VERSION}")

    Puppet.info("upguard: APPLIANCE_URL=#{APPLIANCE_URL}")
    Puppet.info("upguard: PUPPETDB_URL=#{PUPPETDB_URL}")
    Puppet.info("uppuard: COMPILE_MASTER_PEM=#{COMPILE_MASTER_PEM}")
    Puppet.info("upguard: SERVICE_KEY=#{SERVICE_KEY}")
    Puppet.info("upguard: SECRET_KEY=#{SECRET_KEY}")
    Puppet.info("upguard: API_KEY=#{API_KEY}")
    Puppet.info("upguard: SSH_USERNAME=#{SSH_USERNAME}")
    Puppet.info("upguard: SSH_PASSWORD=#{SSH_PASSWORD}")
    Puppet.info("upguard: WINRM_USERNAME=#{WINRM_USERNAME}")
    Puppet.info("upguard: WINRM_PASSWORD=#{WINRM_PASSWORD}")
    Puppet.info("upguard: WINDOWS_CMGS=#{WINDOWS_CMGS}")
    Puppet.info("upguard: SSH_CMGS=#{SSH_CMGS}")

    self.status != nil ? status = self.status : status = 'undefined'

    Puppet.info("upguard: status=#{status}")

    # For most scenarios, make sure the node is added to upguard and is being scanned.
    if status == 'changed'
      node_ip_hostname = self.host
      manifest_filename = get_manifest_files(self.logs)

      Puppet.info("#{log_prefix} node_ip_hostname=#{node_ip_hostname}")
      Puppet.info("#{log_prefix} manifest_filename=#{manifest_filename}")

      lookup = node_lookup(API_KEY, APPLIANCE_URL, node_ip_hostname)
      os = get_os(node_ip_hostname)
      Puppet.info("#{log_prefix} os: #{os}")

      # Get the node role and environment from puppet
      trusted_facts = get_trusted_facts(node_ip_hostname)
      node_group_name = get_role(trusted_facts)
      Puppet.info("#{log_prefix} puppet role for node is: role=#{node_group_name}")
      environment_name = get_environment(trusted_facts)
      Puppet.info("#{log_prefix} puppet environment for node is: environment=#{environment_name}")

      # Get node group and environment ids from UpGuard
      if !node_group_name.nil? and !node_group_name.empty?
        # Create the node_group in UpGuard. If it already exists, and error will be returned - just ignore it.
        node_group_id = node_group_create(API_KEY, APPLIANCE_URL, node_group_name)
      end

      if !environment_name.nil? and !environment_name.empty?
        # Create the environment in UpGuard. If it already exists, and error will be returned - just ignore it.
        environment_id = environment_create(API_KEY, APPLIANCE_URL, environment_name)
      end

      if lookup["node_id"]
        node_id = lookup["node_id"]
        Puppet.info("#{log_prefix} node found: node_id=#{node_id}")
      elsif lookup["error"] == "Not Found"
        node_id = node_create(API_KEY, APPLIANCE_URL, node_ip_hostname, os)
        Puppet.info("#{log_prefix} node not found so created: node_id=#{node_id}")
      else
        Puppet.err("#{log_prefix} failed to lookup node: #{lookup}")
        raise StandardError, "#{log_prefix} unable to get a node id: confirm config variables are correct and appliance is reachable"
      end

      # Make sure to add the node to the node group
      if !node_group_id.nil? and !node_group_id.to_s.include?("error")
        add_to_node_group_response = add_to_node_group(API_KEY, APPLIANCE_URL, node_id, node_group_id)
        if !add_to_node_group_response.nil? && add_to_node_group_response.to_s.include?("Node is already in the group")
          Puppet.info("#{log_prefix} node is already in the node group")
        else
          Puppet.info("#{log_prefix} added the node to the node group")
        end
      else
        Puppet.err("#{log_prefix} obtaining node_group_id failed: #{node_group_id}")
      end

      # Make sure to add the node to the environment
      if !environment_id.nil? && !environment_id.to_s.include?("error")
        add_to_environment_response = add_to_environment(API_KEY, APPLIANCE_URL, node_id, environment_id)
        if !add_to_environment_response.nil? && add_to_environment_response.to_s.include?("error")
          Puppet.info("#{log_prefix} node environment_id could not be updated")
        else
          Puppet.info("#{log_prefix} node environment_id updated")
        end
      else
        Puppet.err("#{log_prefix} obtaining environment_id failed: #{environment_id}")
      end

      # Kick off a node scan
      job = node_scan(API_KEY, APPLIANCE_URL, node_id, manifest_filename)
      if job["job_id"]
        Puppet.info("#{log_prefix} node scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{job["job_id"]}/show_job?show_all=true)")
      else
        Puppet.err("#{log_prefix} failed to kick off node scan against #{node_ip_hostname} (#{node_id}): #{job}")
      end

      # Kick off a node vulnerability scan
      vuln_job = node_vuln_scan(API_KEY, APPLIANCE_URL, node_id)
      if vuln_job["job_id"]
        Puppet.info("#{log_prefix} node vulnerability scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{vuln_job["job_id"]}/show_job?show_all=true)")
      else
        Puppet.err("#{log_prefix} failed to kick off node vulnerability scan against #{node_ip_hostname} (#{node_id}): #{vuln_job}")
      end
    end
  end

  def get_trusted_facts(node_ip_hostname)
    response = `curl -X GET #{PUPPETDB_URL}/pdb/query/v4/nodes/#{node_ip_hostname}/facts -d 'query=["in", ["name","certname"], ["extract", ["name","certname"], ["select_fact_contents", ["and", ["=", "path", ["trusted", "authenticated"]], ["=","value","remote"]]]]]' --tlsv1 --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem --cert /etc/puppetlabs/puppet/ssl/certs/#{COMPILE_MASTER_PEM} --key /etc/puppetlabs/puppet/ssl/private_keys/#{COMPILE_MASTER_PEM}`
    Puppet.info("#{log_prefix} trusted facts for #{node_ip_hostname} is: response=#{response}")
    trusted_facts = JSON.load(response)
    trusted_facts
  end

  def get_role(trusted_facts)
    if trusted_facts && trusted_facts[0] && trusted_facts[0]['value'] && trusted_facts[0]['value']['extensions'] && trusted_facts[0]['value']['extensions']['pp_role']
      trusted_facts[0]['value']['extensions']['pp_role']
    else
      nil
    end
  end

  def get_environment(trusted_facts)
    if trusted_facts && trusted_facts[0] && trusted_facts[0]['value'] && trusted_facts[0]['value']['extensions'] && trusted_facts[0]['value']['extensions']['pp_environment']
      trusted_facts[0]['value']['extensions']['pp_environment']
    else
      nil
    end
  end

  def get_os(hostname)
    response = `curl -X GET #{PUPPETDB_URL}/pdb/query/v4/facts/operatingsystem --data-urlencode 'query=["=", "certname", "#{hostname}"]' --tlsv1 --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem --cert /etc/puppetlabs/puppet/ssl/certs/#{COMPILE_MASTER_PEM} --key /etc/puppetlabs/puppet/ssl/private_keys/#{COMPILE_MASTER_PEM}`
    Puppet.info("#{log_prefix} get_os: response=#{response}")
    os_details = JSON.load(response)
    if os_details && os_details[0]
      os_details[0]['value']
    else
      "unknown"
    end
  end

  def get_manifest_files(logs)
    manifest_filename = []
    default = ERB::Util.url_encode("puppet run")

    if logs && logs.any?
      (logs).each do |log|
        Puppet.info("#{log_prefix} log: #{log}")
        if log.file
          Puppet.info("#{log_prefix} log.file: #{log.file}")
          segments = log.file.split("/")
          if segments && segments.any?
            manifest_filename.push(segments.last)
          end
        end
      end
    else
      manifest_filename.push("#{default}")
    end
    if manifest_filename && manifest_filename.any?
      manifest_filename = manifest_filename.uniq.sort
      ERB::Util.url_encode(manifest_filename.join(", ").slice(0..40))
    else
      "#{default}"
    end
  end

  # Format logs in a consistent, easily grep-able way
  def log_prefix
    if self.host
      "upguard #{self.host}:"
    else
      "upguard:"
    end
  end

  # Add the node to the node group.
  def add_to_node_group(api_key, instance, node_id, node_group_id)
    Puppet.info("#{log_prefix} node_id=#{node_id}")
    Puppet.info("#{log_prefix} node_group_id=#{node_group_id}")
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/node_groups/#{node_group_id}/add_node.json?node_id=#{node_id}`
    Puppet.info("#{log_prefix} add_to_node_group response=#{response}")
    JSON.load(response)
  end
  module_function :add_to_node_group

  # Add the node to the environment. We do this by updating the node rather than using an add_node endpoint.
  def add_to_environment(api_key, instance, node_id, environment_id)
    Puppet.info("#{log_prefix} node_id=#{node_id}")
    Puppet.info("#{log_prefix} environment_id=#{environment_id}")
    response = `curl -X PUT -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{ "node": { "environment_id": "#{environment_id}", "description": "#{VERSION_TAG}" }}' #{instance}/api/v2/nodes/#{node_id}`
    Puppet.info("#{log_prefix} add_to_environment response=#{response}")
  end
  module_function :add_to_environment

  # Check to see if the node has already been added to UpGuard. If so, return it's node_id.
  def node_lookup(api_key, instance, external_id)
    response = `curl -X GET -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/lookup.json?external_id=#{external_id}`
    Puppet.info("#{log_prefix} node_lookup response=#{response}")
    JSON.load(response)
  end
  module_function :node_lookup

  # We create UpGuard node groups to map to Puppet roles
  def node_group_create(api_key, instance, node_group_name)
    create_response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{ "node_group": { "name": "#{node_group_name}", "description": "#{VERSION_TAG}" }}' #{instance}/api/v2/node_groups`
    Puppet.info("#{log_prefix} node_group_create response=#{create_response}")
    lookup_response = `curl -X GET -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/node_groups/lookup.json?name=#{node_group_name}`
    Puppet.info("#{log_prefix} node_group_lookup response=#{lookup_response}")
    lookup_json = JSON.load(lookup_response)
    if lookup_json and lookup_json['node_group_id']
      lookup_json['node_group_id']
    else
      nil
    end
  end
  module_function :node_group_create

  # We create UpGuard environments to map to Puppet environments
  def environment_create(api_key, instance, environment_name)
    create_response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{ "environment": { "name": "#{environment_name}", "short_description": "#{VERSION_TAG}" }}' #{instance}/api/v2/environments`
    Puppet.info("#{log_prefix} environment_create response=#{create_response}")
    lookup_response = `curl -X GET -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/environments/lookup.json?name=#{environment_name}`
    Puppet.info("#{log_prefix} environment_lookup response=#{lookup_response}")
    lookup_json = JSON.load(lookup_response)
    if lookup_json and lookup_json['environment_id']
      lookup_json['environment_id']
    else
      nil
    end
  end
  module_function :environment_create

  # Creates the node in UpGuard
  def node_create(api_key, instance, ip_hostname, os)
    cm_group_id = determine_cm(ip_hostname, os)
    Puppet.info("#{log_prefix} node_create ip_hostname=#{ip_hostname}")
    Puppet.info("#{log_prefix} node_create os=#{os}")
    Puppet.info("#{log_prefix} node_create cm_group_id=#{cm_group_id}")

    node = {}
    node[:node] = {}
    node[:node][:name] = "#{ip_hostname}"
    node[:node][:external_id] = "#{ip_hostname}"
    node[:node][:medium_hostname] = "#{ip_hostname}"
    node[:node][:short_description] = "#{VERSION_TAG}"
    node[:node][:connection_manager_group_id] = "#{cm_group_id}"

    if os && os.downcase == 'windows'
      node[:node][:node_type] = "SV" # Server
      node[:node][:operating_system_family_id] = 1
      node[:node][:operating_system_id] = 125 # Windows 2012
      node[:node][:medium_type] = 7 # WinRM
      node[:node][:medium_port] = 5985
      node[:node][:medium_username] = "#{WINRM_USERNAME}"
      node[:node][:medium_password] = "#{WINRM_PASSWORD}"
    elsif os && os.downcase == 'centos'
      node[:node][:node_type] = "SV"
      node[:node][:operating_system_family_id] = 2
      node[:node][:operating_system_id] = 231 # CentOS
      node[:node][:medium_type] = 3 # SSH
      node[:node][:medium_port] = 22
      node[:node][:medium_username] = "#{SSH_USERNAME}"
      node[:node][:medium_password] = "#{SSH_PASSWORD}"
    else # Add the node as a network device...
      node[:node][:node_type] = "FW" # Firewall
      node[:node][:operating_system_family_id] = 7
      node[:node][:operating_system_id] = 731 # Cisco ASA
      node[:node][:medium_type] = 3 # SSH
      node[:node][:medium_port] = 22
      node[:node][:medium_username] = "#{SSH_USERNAME}"
      node[:node][:medium_password] = "#{SSH_PASSWORD}"
    end

    request = "curl -X POST -s -k -H 'Authorization: Token token=\"#{api_key}\"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '#{node.to_json}' #{instance}/api/v2/nodes"
    Puppet.info("#{log_prefix} node_create request=#{request}")
    response = `#{request}`
    Puppet.info("#{log_prefix} node_create response=#{response}")
    node = JSON.load(response)

    if node["id"]
      if os && os.downcase != 'windows' && os.downcase != 'centos'
        Puppet.info("#{log_prefix} adding node to unclassified node group")
        unclassified_resp = add_to_node_group(api_key, instance, node["id"], 29)
        Puppet.info("#{log_prefix} adding node to unclassified node group response=#{unclassified_resp}")
      end

      node["id"]
    else
      Puppet.err("#{log_prefix} failed to create node: #{ip_hostname}")
      raise StandardError, "#{log_prefix} unable to create node: confirm node parameters are correct"
    end
  end
  module_function :node_create

  # Kick off a node scan
  def node_scan(api_key, instance, node_id, tag)
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/#{node_id}/start_scan.json`
    Puppet.info("#{log_prefix} node_scan response=#{response}")
    JSON.load(response)
  end
  module_function :node_scan

  # Kick off a vulnerability scan
  def node_vuln_scan(api_key, instance, node_id)
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' '#{instance}/api/v2/jobs.json?type=node_vulns&vuln_limit=5000&vuln_severity=5&type_id=#{node_id}'`
    Puppet.info("#{log_prefix} node_vuln_scan response=#{response}")
    JSON.load(response)
  end
  module_function :node_vuln_scan

  # Determine the correct UpGuard connection manager to scan the node with.
  def determine_cm(node_name, node_os)
    cmgs = nil
    default_cmg = 1

    # Return the default connection manager group if a node name or node os isn't provided
    if node_name.nil? || node_os.nil?
      Puppet.info("#{log_prefix} node name or node os not provided, using default connection manager group")
      return default_cmg
    end
    # Downcase once here for further work
    node_name = node_name.downcase
    node_os   = node_os.downcase

    # Based on the nodes OS type, assign the relevent connection manager group over for searching.
    if node_os == 'windows'
      cmgs = WINDOWS_CMGS
    else
      cmgs = SSH_CMGS
    end

    unless cmgs.nil?
      cmgs.each do |c|
        # Skip element if it's not formatted correctly
        next if c['domain'].nil? || c['id'].nil?
        cmg_domain = c['domain']
        cmg_id = c['id']
        if node_name.end_with?(cmg_domain)
          Puppet.info("#{log_prefix} assigning #{node_name} to connection manager group #{cmg_domain} (Id: #{cmg_id})")
          # Stop searching, we have found a connection manager group we can use
          return "#{cmg_id}"
        end
      end
    end

    # If we got here then we have a node with a domain that isn't mapped to connection manager domain
    Puppet.info("#{log_prefix} windows node #{node_name} could not be mapped to a connection manager group, using default connection manager group instead")
    return default_cmg
  end
  module_function :determine_cm
end
