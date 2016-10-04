require 'puppet'
require 'json'
require 'erb'

Puppet::Reports.register_report(:upguard) do

  Puppet.info("upguard: starting report processor v1.0.0")

  desc "Create a node (if not present) and kick off a node scan in UpGuard if changes were made."

  configfile = File.join([File.dirname(Puppet.settings[:config]), "upguard.yaml"])
  raise(Puppet::ParseError, "upguard.yaml config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError => e
    raise(Puppet::ParserError, "upguard.yaml file is invalid")
  end

  APPLIANCE_URL                 = config[:appliance_url]
  PUPPETDB_URL                  = config[:puppetdb_url]
  COMPILE_MASTER_PEM            = config[:compile_master_pem]
  SERVICE_KEY                   = config[:service_key]
  SECRET_KEY                    = config[:secret_key]
  API_KEY                       = "#{SERVICE_KEY}#{SECRET_KEY}"
  SSH_CM_GROUP_ONE_DOMAIN       = config[:ssh_cm_group_one_domain]  
  SSH_CM_GROUP_ONE_ID           = config[:ssh_cm_group_one_id]
  WINDOWS_CM_GROUP_ONE_DOMAIN   = config[:windows_cm_group_one_domain]
  WINDOWS_CM_GROUP_ONE_ID       = config[:windows_cm_group_one_id]
  WINDOWS_CM_GROUP_TWO_DOMAIN   = config[:windows_cm_group_two_domain]
  WINDOWS_CM_GROUP_TWO_ID       = config[:windows_cm_group_two_id]
  WINDOWS_CM_GROUP_THREE_DOMAIN = config[:windows_cm_group_three_domain]
  WINDOWS_CM_GROUP_THREE_ID     = config[:windows_cm_group_three_id]
  WINDOWS_CM_GROUP_FOUR_DOMAIN  = config[:windows_cm_group_four_domain]
  WINDOWS_CM_GROUP_FOUR_ID      = config[:windows_cm_group_four_id]
  WINDOWS_CM_GROUP_FIVE_DOMAIN  = config[:windows_cm_group_five_domain]
  WINDOWS_CM_GROUP_FIVE_ID      = config[:windows_cm_group_five_id]
  WINDOWS_CM_GROUP_SIX_DOMAIN   = config[:windows_cm_group_six_domain]
  WINDOWS_CM_GROUP_SIX_ID       = config[:windows_cm_group_six_id]
  WINDOWS_CM_GROUP_SEVEN_DOMAIN = config[:windows_cm_group_seven_domain]
  WINDOWS_CM_GROUP_SEVEN_ID     = config[:windows_cm_group_seven_id]
  WINDOWS_CM_GROUP_EIGHT_DOMAIN = config[:windows_cm_group_eight_domain]
  WINDOWS_CM_GROUP_EIGHT_ID     = config[:windows_cm_group_eight_id]

  Puppet.info("upguard: APPLIANCE_URL=#{APPLIANCE_URL}")
  Puppet.info("upguard: PUPPETDB_URL=#{PUPPETDB_URL}")
  Puppet.info("uppuard: COMPILE_MASTER_PEM=#{COMPILE_MASTER_PEM}")
  Puppet.info("upguard: SERVICE_KEY=#{SERVICE_KEY}")
  Puppet.info("upguard: SECRET_KEY=#{SECRET_KEY}")
  Puppet.info("upguard: API_KEY=#{API_KEY}")
  Puppet.info("upguard: SSH_CM_GROUP_ONE_DOMAIN=#{SSH_CM_GROUP_ONE_DOMAIN}")
  Puppet.info("upguard: SSH_CM_GROUP_ONE_ID=#{SSH_CM_GROUP_ONE_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_ONE_DOMAIN=#{WINDOWS_CM_GROUP_ONE_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_ONE_ID=#{WINDOWS_CM_GROUP_ONE_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_TWO_DOMAIN=#{WINDOWS_CM_GROUP_TWO_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_TWO_ID=#{WINDOWS_CM_GROUP_TWO_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_THREE_DOMAIN=#{WINDOWS_CM_GROUP_THREE_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_THREE_ID=#{WINDOWS_CM_GROUP_THREE_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_FOUR_DOMAIN=#{WINDOWS_CM_GROUP_FOUR_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_FOUR_ID=#{WINDOWS_CM_GROUP_FOUR_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_FIVE_DOMAIN=#{WINDOWS_CM_GROUP_FIVE_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_FIVE_ID=#{WINDOWS_CM_GROUP_FIVE_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_SIX_DOMAIN=#{WINDOWS_CM_GROUP_SIX_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_SIX_ID=#{WINDOWS_CM_GROUP_SIX_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_SEVEN_DOMAIN=#{WINDOWS_CM_GROUP_SEVEN_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_SEVEN_ID=#{WINDOWS_CM_GROUP_SEVEN_ID}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_EIGHT_DOMAIN=#{WINDOWS_CM_GROUP_EIGHT_DOMAIN}")
  Puppet.info("upguard: WINDOWS_CM_GROUP_EIGHT_ID=#{WINDOWS_CM_GROUP_EIGHT_ID}")

  def process

    self.status != nil ? status = self.status : status = 'undefined'

    Puppet.info("upguard: status=#{status}")

    # For most scenarios, make sure the node is added to upguard and is being scanned.
    if status == 'changed'
      node_ip_hostname = self.host
      manifest_filename = get_manifest_files(self.logs)

      Puppet.info("upguard: node_ip_hostname=#{node_ip_hostname}")
      Puppet.info("upguard: manifest_filename=#{manifest_filename}")

      lookup = node_lookup(API_KEY, APPLIANCE_URL, node_ip_hostname)
      os = get_os(node_ip_hostname)
      Puppet.info("upguard: os: #{os}")
      node_group_name = get_role(node_ip_hostname)
      Puppet.info("upguard: puppet role for node is: role=#{node_group_name}")
      if !node_group_name.nil? and !node_group_name.empty?
        # Create the node_group in UpGuard. If it already exists, and error will be returned - just ignore it.
        node_group_id = node_group_create(API_KEY, APPLIANCE_URL, node_group_name)
      end

      if lookup["node_id"]
        node_id = lookup["node_id"]
        Puppet.info("upguard: node found: node_id=#{node_id}")
      elsif lookup["error"] == "Not Found"
        node_id = node_create(API_KEY, APPLIANCE_URL, node_ip_hostname, os)
        Puppet.info("upguard: node not found so created: node_id=#{node_id}")
      else
        Puppet.err("upguard: failed to lookup node: #{lookup}")
        raise StandardError, "upguard: unable to get a node id: confirm config variables are correct and appliance is reachable"
      end

      # Make sure to add the node to the node group
      if !node_group_id.nil? and !node_group_id.to_s.include?("error")
        add_to_node_group_response = add_to_node_group(API_KEY, APPLIANCE_URL, node_id, node_group_id)
        if !add_to_node_group_response.nil? && add_to_node_group_response.to_s.include?("Node is already in the group")
          Puppet.info("upguard: node is already in the node group")
        else
          Puppet.info("upguard: added the node to the node group")
        end
      else
        Puppet.err("upguard: obtaining node_group_id failed: #{node_group_id}")
      end

      # Kick off a node scan
      job = node_scan(API_KEY, APPLIANCE_URL, node_id, manifest_filename)
      if job["job_id"]
        Puppet.info("upguard: node scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{job["job_id"]}/show_job?show_all=true)")
      else
        Puppet.err("upguard: failed to kick off node scan against #{node_ip_hostname} (#{node_id}): #{job}")
      end

      # Kick off a node vulnerability scan
      # vuln_job = node_vuln_scan(API_KEY, APPLIANCE_URL, node_id)
      # if vuln_job["job_id"]
      #   Puppet.info("upguard: node vulnerability scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{vuln_job["job_id"]}/show_job?show_all=true)")
      # else
      #   Puppet.err("upguard: failed to kick off node vulnerability scan against #{node_ip_hostname} (#{node_id}): #{vuln_job}")
      # end
    end
  end

  def get_role(node_ip_hostname)
    response = `curl -X GET #{PUPPETDB_URL}/pdb/query/v4/nodes/#{node_ip_hostname}/facts -d 'query=["in", ["name","certname"], ["extract", ["name","certname"], ["select_fact_contents", ["and", ["=", "path", ["trusted", "authenticated"]], ["=","value","remote"]]]]]' --tlsv1 --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem --cert /etc/puppetlabs/puppet/ssl/certs/#{COMPILE_MASTER_PEM} --key /etc/puppetlabs/puppet/ssl/private_keys/#{COMPILE_MASTER_PEM}`
    Puppet.info("upguard: role via trusted facts for #{node_ip_hostname} is: response=#{response}")
    role_details = JSON.load(response)
    if role_details && role_details[0] && role_details[0]['value'] && role_details[0]['value']['extensions'] && role_details[0]['value']['extensions']['pp_role']
      role_details[0]['value']['extensions']['pp_role']
    else
      nil
    end
  end

  def get_os(hostname)
    response = `curl -X GET #{PUPPETDB_URL}/pdb/query/v4/facts/operatingsystem --data-urlencode 'query=["=", "certname", "#{hostname}"]' --tlsv1 --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem --cert /etc/puppetlabs/puppet/ssl/certs/#{COMPILE_MASTER_PEM} --key /etc/puppetlabs/puppet/ssl/private_keys/#{COMPILE_MASTER_PEM}`
    Puppet.info("upguard: get_os: response=#{response}")
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
        Puppet.info("upguard: log: #{log}")
        if log.file
          Puppet.info("upguard: log.file: #{log.file}")
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

  # Add the node to the node group
  def add_to_node_group(api_key, instance, node_id, node_group_id)
    Puppet.info("upguard: node_id=#{node_id}")
    Puppet.info("upguard: node_group_id=#{node_group_id}")
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/node_groups/#{node_group_id}/add_node.json?node_id=#{node_id}`
    Puppet.info("upguard: add_to_node_group response=#{response}")
    JSON.load(response)
  end
  module_function :add_to_node_group

  # Check to see if the node has already been added to UpGuard. If so, return it's node_id.
  def node_lookup(api_key, instance, external_id)
    response = `curl -X GET -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/lookup.json?external_id=#{external_id}`
    Puppet.info("upguard: node_lookup response=#{response}")
    JSON.load(response)
  end
  module_function :node_lookup

  # We create UpGuard node groups to map to Puppet roles
  def node_group_create(api_key, instance, node_group_name)
    create_response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{ "node_group": { "name": "#{node_group_name}" }}' #{instance}/api/v2/node_groups`
    Puppet.info("upguard: node_group_create response=#{create_response}")
    lookup_response = `curl -X GET -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/node_groups/lookup.json?name=#{node_group_name}`
    Puppet.info("upguard: node_group_lookup response=#{lookup_response}")
    lookup_json = JSON.load(lookup_response)
    if lookup_json and lookup_json['node_group_id']
      lookup_json['node_group_id']
    else
      nil
    end
  end
  module_function :node_group_create

  # Creates the node in UpGuard
  def node_create(api_key, instance, ip_hostname, os)
    cm_group_id = determine_cm(ip_hostname, os)
    Puppet.info("upguard: node_create ip_hostname=#{ip_hostname}")
    Puppet.info("upguard: node_create os=#{os}")
    Puppet.info("upguard: node_create cm_group_id=#{cm_group_id}")
    if os && os.downcase == 'windows'
      node_details = '{ "node": { "name": ' + "\"#{ip_hostname}\"" + ', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": 1, "operating_system_id": 125, "medium_type": 7, "medium_port": 5985, "connection_manager_group_id": ' + "\"#{cm_group_id}\"" + ', "medium_hostname": ' + "\"#{ip_hostname}\"" + ', "external_id": ' + "\"#{ip_hostname}\"" + '}}'
      response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '#{node_details}' #{instance}/api/v2/nodes`
    elsif os && os.downcase == 'centos'
      node_details = '{ "node": { "name": ' + "\"#{ip_hostname}\"" + ', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": 2, "operating_system_id": 231, "medium_type": 3, "medium_port": 22, "connection_manager_group_id": ' + "\"#{cm_group_id}\"" + ', "medium_username": "svc-upguard-lnx", "medium_hostname": ' + "\"#{ip_hostname}\"" + ', "external_id": ' + "\"#{ip_hostname}\"" + '}}'
      response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '#{node_details}' #{instance}/api/v2/nodes`
    else
      node_details = '{ "node": { "name": ' + "\"#{ip_hostname}\"" + ', "short_description": "Added via the API.", "node_type": "SV", "operating_system_family_id": 7, "operating_system_id": 731, "medium_type": 3, "medium_port": 22, "connection_manager_group_id": ' + "\"#{cm_group_id}\"" + ', "medium_username": "svc-upguard-lnx", "medium_hostname": ' + "\"#{ip_hostname}\"" + ', "external_id": ' + "\"#{ip_hostname}\"" + '}}'
      response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' -d '#{node_details}' #{instance}/api/v2/nodes`
    end
    Puppet.info("upguard: node_create response=#{response}")
    node = JSON.load(response)

    if node["id"]
      if os && os.downcase != 'windows' && os.downcase != 'centos'
        Puppet.info("upguard: adding node to unclassified node group")
        unclassified_resp = add_to_node_group(api_key, instance, node["id"], 29)
        Puppet.info("upguard: adding node to unclassified node group response=#{unclassified_resp}")
      end

      node["id"]
    else
      Puppet.err("upguard: failed to create node: #{ip_hostname}")
      raise StandardError, "upguard: unable to create node: confirm node parameters are correct"
    end
  end
  module_function :node_create

  # Kick off a node scan
  def node_scan(api_key, instance, node_id, tag)
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' #{instance}/api/v2/nodes/#{node_id}/start_scan.json`
    Puppet.info("upguard: node_scan response=#{response}")
    JSON.load(response)
  end
  module_function :node_scan

  # Kick off a vulnerability scan
  def node_vuln_scan(api_key, instance, node_id)
    response = `curl -X POST -s -k -H 'Authorization: Token token="#{api_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' '#{instance}/api/v2/jobs.json?type=node_vulns&type_id=#{node_id}'`
    Puppet.info("upguard: node_vuln_scan response=#{response}")
    JSON.load(response)
  end
  module_function :node_vuln_scan

  # Determine the correct UpGuard connection manager to scan the node with.
  def determine_cm(node_name, node_os)
    return "#{SSH_CM_GROUP_ONE_ID}" if node_name.nil? || node_os.nil?
    node_name = node_name.downcase
    node_os   = node_os.downcase
    # If the node is anything other than Windows return the Id of the Default/Appliance connection manager.
    return "#{SSH_CM_GROUP_ONE_ID}" if node_os != 'windows'
    # We have a non-Windows node
    if node_name.end_with?("#{WINDOWS_CM_GROUP_ONE_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_ONE_ID}"
    elsif node_name.end_with?("#{WINDOWS_CM_GROUP_TWO_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_TWO_ID}"
    elsif node_name.end_with?("#{WINDOWS_CM_GROUP_THREE_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_THREE_ID}"
    elsif node_name.end_with?("#{WINDOWS_CM_GROUP_FOUR_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_FOUR_ID}"
    elsif node_name.end_with?("#{WINDOWS_CM_GROUP_FIVE_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_FIVE_ID}"
    elsif node_name.end_with?("#{WINDOWS_CM_GROUP_SIX_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_SIX_ID}"
    elsif node_name.end_with?("#{WINDOWS_CM_GROUP_SEVEN_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_SEVEN_ID}"
    elsif node_name.end_with?("#{WINDOWS_CM_GROUP_EIGHT_DOMAIN}")
      return "#{WINDOWS_CM_GROUP_EIGHT_ID}"
    else
      # Use the default connection manager Id as the fallback
      return "#{SSH_CM_GROUP_ONE_ID}"
    end
  end
  module_function :determine_cm
end
