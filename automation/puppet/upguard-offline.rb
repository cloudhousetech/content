require 'puppet'
require 'json'
require 'erb'

# TODO: What should this wrapper be? Is it still getting called from within Puppet
Puppet::Reports.process_offline(:upguard) do

  VERSION = "v1.5.4"   # Keep in sync with upguard.rb
  CONFIG_FILE_NAME = "upguard.yaml"
  VERSION_TAG = "Added by #{File.basename(__FILE__)} #{VERSION}"
  desc "Bulk processing of puppet run nodes that occurred when UpGuard was offline."

  # TODO: Can we grab this file like this? Related to first question of whether this is running in a Puppet context
  configfile = File.join([File.dirname(Puppet.settings[:config]), CONFIG_FILE_NAME])
  raise(Puppet::ParseError, "#{CONFIG_FILE_NAME} config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError => e
    raise(Puppet::ParserError, "#{CONFIG_FILE_NAME} file is invalid")
  end

  CONFIG                   = config
  APPLIANCE_URL            = config[:appliance_url]
  PUPPETDB_URL             = config[:puppetdb_url]
  COMPILE_MASTER_PEM       = config[:compile_master_pem]
  SERVICE_KEY              = config[:service_key]
  SECRET_KEY               = config[:secret_key]
  API_KEY                  = "#{SERVICE_KEY}#{SECRET_KEY}"
  CM                       = config[:sites]
  ENVIRONMENT              = config[:environment]
  TEST_OS                  = config[:test_os]
  TEST_OS_MAJOR_RELEASE    = config[:test_os_major_release]
  TEST_OS_VIRT_PLATFORM    = config[:test_os_virt_platform]
  TEST_NODE_NAME           = config[:test_node_name]
  TEST_LINUX_HOSTNAME      = config[:test_linux_hostname]
  TEST_WINDOWS_HOSTNAME    = config[:test_windows_hostname]
  UNKNOWN_OS_NODE_GROUP_ID = config[:unknown_os_node_group_id]
  SLEEP_BEFORE_SCAN        = config[:sleep_before_scan]
  IGNORE_HOSTNAME_INCLUDE  = config[:ignore_hostname_include]
  OFFLINE_MODE_FILENAME    = config[:offline_mode_filename]
  UPGUARD_CURL_FLAGS       = "-s -k -H 'Authorization: Token token=\"#{API_KEY}\"' -H 'Accept: application/json' -H 'Content-Type: application/json'"

  def process
    Puppet.info("#{log_prefix} starting bulk processor #{VERSION}")

    self.status != nil ? status = self.status : status = 'undefined'
    Puppet.info("#{log_prefix} status=#{status}")

    if test_env
      # Unchanged here so that you can run `puppet-agent -t` over and over.
      run_states = %w(unchanged)
    else
      run_states = %w(changed failed)
    end

    # For most scenarios, make sure the node is added to upguard and is being scanned.
    unless run_states.include?(status)
      Puppet.info("#{log_prefix} returning early, '#{status}' not in run_states")
      return
    end

    # Check that all the variables we need supplied from upguard.yaml are present and return if they are not.
    if config_variables_missing
      Puppet.info("#{log_prefix} returning early, ensure that missing config variables are present in #{CONFIG_FILE_NAME}")
      return
    end
    
    # Check to see if we need to operate in offline mode as UpGuard may not always be available.
    if upguard_offline
      Puppet.info("#{log_prefix} returning early, '#{APPLIANCE_URL}' is offline")
      return
    else
      if File.exists?(OFFLINE_MODE_FILENAME)
        # We're back online, but have a backlog of nodes to process.
        Puppet.info("#{log_prefix} #{OFFLINE_MODE_FILENAME} present, working through puppet runs backlog")
        file_state = File.read(OFFLINE_MODE_FILENAME)
        puppet_runs = JSON.parse(file_state)
        process_backlog
        if !puppet_runs.nil? && puppet_runs.any?
          unique_puppet_runs = puppet_runs.uniq {|r| r['node_ip_hostname']}
          unique_puppet_runs.each do |run|
            provision_node_in_upguard(run)
          end
        else
          Puppet.info("#{log_prefix} #{OFFLINE_MODE_FILENAME} present, but an array of puppet runs not found, removing")
        end
        # Finally, remove the state file
        FileUtils.rm(OFFLINE_MODE_FILENAME)
      end
    end
  end

  ##############################################################################
  # DRIVER METHODS                                                             #
  ##############################################################################

  def config_variables_missing
    config_vars_missing  = false
    required_config_vars = [:appliance_url, :puppetdb_url, :compile_master_pem, :service_key, :secret_key, :sites,
                            :environment, :unknown_os_node_group_id, :sleep_before_scan, :ignore_hostname_include,
                            :offline_mode_filename]
    required_config_vars.each do |required_var|
      if !CONFIG.key?(required_var)
        Puppet.info("#{log_prefix} config variable '#{required_var}' is missing")
        config_vars_missing = true
      else
        dont_print_vars = [:service_key, :secret_key, :sites]
        unless dont_print_vars.include?(required_var)
          Puppet.info("#{log_prefix} #{required_var}=#{CONFIG[required_var]}")
        end
      end
    end
    config_vars_missing
  end

  def provision_node_in_upguard(puppet_run)
    # Get node group id from UpGuard
    role_node_group_id = lookup_or_create_node_group(puppet_run['node_group_name'], nil)
    # E.g. AWS CentOS 7, Baremetal Windows 2012
    platform_os_version = "#{puppet_run['virt_platform']} #{puppet_run['os']} #{puppet_run['os_version']}".strip
    Puppet.info("#{log_prefix} platform_os_version=#{platform_os_version}")
    os_node_group_id = lookup_or_create_node_group(platform_os_version, nil)
    # Get environment id from UpGuard
    environment_id = lookup_or_create_environment(puppet_run['environment_name'])
    # Determine if we can find the node or if we need to create it
    node = lookup_or_create_node(puppet_run['node_ip_hostname'], puppet_run['os'], puppet_run['datacenter_name'])
    # Make sure to add the node to the node group
    add_node_to_group(node[:id], role_node_group_id)
    add_node_to_group(node[:id], os_node_group_id)
    # Make sure to add the node to the environment
    add_node_to_environment(node[:id], environment_id)

    # For new nodes, sleep to let Puppet catch up
    if node[:created]
      Puppet.info("#{log_prefix} new node, sleeping for #{SLEEP_BEFORE_SCAN} seconds...")
      sleep SLEEP_BEFORE_SCAN
      # Kick off a vuln scan only for newly created nodes
      #vuln_scan(node[:id], node_ip_hostname)
    end
    node_scan(node[:id], puppet_run['node_ip_hostname'], puppet_run['manifest_filename'])
  end

  def store_puppet_run(offline_mode_filename, puppet_run)
    # Take all the info about the node from PDB and store it to file.
    Puppet.info("#{log_prefix} puppet_run: #{puppet_run}")
    if File.exists?(offline_mode_filename)
      # Read in existing state file.
      Puppet.info("#{log_prefix} state file already exists, reading in contents")
      file_state = File.read(offline_mode_filename)
      puppet_runs = JSON.parse(file_state)
    else
      Puppet.info("#{log_prefix} state file not present, creating one now")
      puppet_runs = []
    end
    puppet_runs << puppet_run
    # Write the array back to the state file
    Puppet.info("#{log_prefix} added '#{puppet_run['node_ip_hostname']}' to the state file to process when upguard is back online")
    File.write(offline_mode_filename, JSON.pretty_generate(puppet_runs))
  end

  def upguard_offline
    offline_status = true
    # Perform an authenticated request to UpGuard. This additionally proves that ones auth credentials are correct.
    response = `curl -X GET -m 20 #{UPGUARD_CURL_FLAGS} #{APPLIANCE_URL}/api/v2/users`
    Puppet.info("#{log_prefix} user_lookup response=#{response}")
    if !response.nil? && response.include?("email")
      offline_status = false
    end
    offline_status
  end

  def generate_environment_name(datacenter_name, environment_name)
    if (!datacenter_name.nil? && !datacenter_name.empty?) && (!environment_name.nil? && !environment_name.empty?)
      datacenter_environment_name = "#{datacenter_name}_#{environment_name}"
      Puppet.err("#{log_prefix} datacenter_environment_name=#{datacenter_environment_name}")
      datacenter_environment_name
    else
      Puppet.err("#{log_prefix} either pp_datacenter (#{datacenter_name}) or pp_environment (#{environment_name}) is nil or empty")
      "tf_problem"
    end
  end

  def lookup_or_create_node_group(node_group_name, node_group_rule)
    if !node_group_name.nil? && !node_group_name.empty?
      # Create the node_group in UpGuard. If it already exists, and error will be returned - just ignore it.
      node_group_id = upguard_node_group_create(node_group_name, node_group_rule)
      Puppet.info("#{log_prefix} node group found/created: node_group_id=#{node_group_id}")
      node_group_id
    else
      Puppet.err("#{log_prefix} node group name nil or empty, skipping lookup/creation")
      nil
    end
  end

  def lookup_or_create_environment(environment_name)
    if !environment_name.nil? && !environment_name.empty?
      # Create the environment in UpGuard. If it already exists, and error will be returned - just ignore it.
      environment_id = upguard_environment_create(environment_name)
      Puppet.info("#{log_prefix} environment found/created: environment_id=#{environment_id}")
      environment_id
    else
      Puppet.err("#{log_prefix} environment name nil or empty, skipping lookup/creation")
      nil
    end
  end

  def lookup_or_create_node(node_ip_hostname, os, datacenter_name)
    node = {}
    lookup = upguard_node_lookup(node_ip_hostname)
    if !lookup.nil? && !lookup["node_id"].nil?
      node[:id] = lookup["node_id"]
      node[:created] = false
      Puppet.info("#{log_prefix} node already exists: node[:id]=#{node[:id]}")
      node
    elsif !lookup.nil? && !lookup["error"].nil? && (lookup["error"] == "Not Found")
      node[:id] = upguard_node_create(node_ip_hostname, os, datacenter_name)
      node[:created] = true
      Puppet.info("#{log_prefix} node not found so created: node[:id]=#{node[:id]}")
      node
    else
      Puppet.err("#{log_prefix} failed to lookup node: #{lookup}")
      raise StandardError, "#{log_prefix} unable to get a node id: confirm config variables are correct and upguard appliance is reachable"
    end
  end

  def add_node_to_group(node_id, node_group_id)
    if !node_group_id.nil? && !node_group_id.to_s.include?("error")
      add_to_node_group_response = upguard_add_to_node_group(node_id, node_group_id)
      if !add_to_node_group_response.nil? && add_to_node_group_response.to_s.include?("Node is already in the group")
        Puppet.info("#{log_prefix} node is already in the node group")
      else
        Puppet.info("#{log_prefix} added the node to the node group")
      end
    else
      Puppet.err("#{log_prefix} obtaining node_group_id failed: #{node_group_id}")
    end
  end

  def add_node_to_environment(node_id, environment_id)
    if !environment_id.nil? && !environment_id.to_s.include?("error")
      add_to_environment_response = upguard_add_to_environment(node_id, environment_id)
      if !add_to_environment_response.nil? && add_to_environment_response.to_s.include?("error")
        Puppet.info("#{log_prefix} node environment_id could not be updated")
      else
        Puppet.info("#{log_prefix} node environment_id updated")
      end
    else
      Puppet.err("#{log_prefix} obtaining environment_id failed: #{environment_id}")
    end
  end

  def node_scan(node_id, node_ip_hostname, manifest_filename)
    job = upguard_node_scan(node_id, manifest_filename)
    if job["job_id"]
      Puppet.info("#{log_prefix} node scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{job["job_id"]}/show_job?show_all=true)")
    else
      Puppet.err("#{log_prefix} failed to kick off node scan against #{node_ip_hostname} (#{node_id}): #{job}")
    end
  end

  def vuln_scan(node_id, node_ip_hostname)
    vuln_job = upguard_node_vuln_scan(node_id)
    if vuln_job["job_id"]
      Puppet.info("#{log_prefix} node vulnerability scan kicked off against #{node_ip_hostname} (#{APPLIANCE_URL}/jobs/#{vuln_job["job_id"]}/show_job?show_all=true)")
    else
      Puppet.err("#{log_prefix} failed to kick off node vulnerability scan against #{node_ip_hostname} (#{node_id}): #{vuln_job}")
    end
  end

  #############################################################################
  # HELPER METHODS                                                            #
  #############################################################################

  # Used for debugging (shortcuts needing to use PDB).
  def test_env
    if ENVIRONMENT.is_a?(String) && ENVIRONMENT == "test"
      true
    else
      false
    end
  end

  # Format logs in a consistent, easily grep-able way.
  def log_prefix
    if self.host
      "upguard #{self.host}:"
    else
      "upguard:"
    end
  end

  # Determine the correct UpGuard connection manager to scan the node with.
  def determine_domain_details(node_name, node_os, datacenter_name)
    default_cmg_details = {}
    default_cmg_details['id'] = 1
    default_cmg_details['service_account'] = ""
    default_cmg_details['service_password'] = ""

    # Return the default connection manager group if a node name or node os isn't provided
    if node_name.nil? || node_os.nil?
      Puppet.info("#{log_prefix} node name or node os not provided, using default connection manager group")
      return default_cmg_details
    end
    # Downcase once here for further work
    node_name = node_name.downcase
    node_os   = node_os.downcase

    if CM.is_a?(Array) && CM.any?
      CM.each do |site|
        site_name = site['name']
        next if site_name.nil?
        next unless site_name == datacenter_name
        domains = site['domains']

        if domains.is_a?(Array) && domains.any?
          domains.each do |domain|
            # Skip element if it's not formatted correctly
            domain_name = domain['name']
            next if domain_name.nil?
            next unless node_name.end_with?(domain_name)

            if node_os == 'windows'
              windows_cmgs = domain['windows_connection_manager_groups']
              # Check that we have a Windows connection manager group for the given domain
              if windows_cmgs.is_a?(Array) && windows_cmgs.any?
                # Make sure the domain has a node group created for it (this helps with creating variable overrides)
                # The node group rule here will automatically add the node to the node group (and other others)
                lookup_or_create_node_group(domain_name, ".+#{domain_name}$")
                # Multiple (Windows) connection manager groups can be defined for a domain.
                # Currently, we just use the first.
                return windows_cmgs[0]
              end
            else
              ssh_cmgs = domain['ssh_connection_manager_groups']
              if ssh_cmgs.is_a?(Array) && ssh_cmgs.any?
                # Make sure the domain has a node group created for it (this helps with creating variable overrides)
                lookup_or_create_node_group(domain_name, ".+#{domain_name}$")
                return ssh_cmgs[0]
              end
            end
          end
        end
      end

      # If we got here then we have a node with a domain that isn't mapped to a connection manager group
      Puppet.info("#{log_prefix} #{node_name} could not be mapped to a connection manager group, using default connection manager group instead")
      return default_cmg_details
    end
  end

  #############################################################################
  # PUPPET DB (PDB) METHODS                                                   #
  #############################################################################

  # Hostname is a variable we can source from "self".
  def pdb_get_hostname(node_ip_hostname)
    if test_env
      node_ip_hostname = TEST_NODE_NAME
      Puppet.info("#{log_prefix} node_ip_hostname=#{node_ip_hostname}")
      node_ip_hostname
    else
      Puppet.info("#{log_prefix} node_ip_hostname=#{node_ip_hostname}")
      node_ip_hostname
    end
  end

  # Get trusted facts from Puppet.
  def pdb_get_facts(node_ip_hostname)
    keyed_facts = {}

    if test_env
      response = "[{\"certname\":\"host-name-01.domain.com\",\"name\":\"trusted\",\"value\":{\"authenticated\":\"remote\",\"certname\":\"host-name-01.domain.com\",\"domain\":\"domain.com\",\"extensions\":{\"company_trusted_swimlane\":\"n/a\",\"pp_datacenter\":\"mtv\",\"pp_environment\":\"qa\",\"pp_product\":\"test\",\"pp_role\":\"rabbit_mq\"},\"hostname\":\"host-name-01\"},\"environment\":\"tier2\"},{\"certname\":\"puppet.upguard.org\",\"environment\":\"production\",\"name\":\"virtual\",\"value\":\"#{TEST_OS_VIRT_PLATFORM}\"},{\"certname\":\"puppet.upguard.org\",\"environment\":\"production\",\"name\":\"operatingsystemmajrelease\",\"value\":\"#{TEST_OS_MAJOR_RELEASE}\"},{\"certname\":\"puppet.upguard.org\",\"environment\":\"production\",\"name\":\"operatingsystem\",\"value\":\"#{TEST_OS}\"}]"
    else
      response = `curl -X GET #{PUPPETDB_URL}/pdb/query/v4/nodes/#{node_ip_hostname}/facts -d 'query=["or", ["=","name","trusted"], ["=","name","virtual"], ["=","name","operatingsystem"], ["=","name","operatingsystemmajrelease"]]' --tlsv1 --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem --cert /etc/puppetlabs/puppet/ssl/certs/#{COMPILE_MASTER_PEM} --key /etc/puppetlabs/puppet/ssl/private_keys/#{COMPILE_MASTER_PEM}`
      Puppet.info("#{log_prefix} trusted facts for #{node_ip_hostname} is: response=#{response}")
    end

    if response.nil?
      return nil
    end
    facts = JSON.load(response)
    if !facts.is_a?(Array) && !facts.any?
      return nil
    end
    facts.each do |fact|
      keyed_facts[fact['name']] = fact
    end
    keyed_facts
  end

  # Extract out the role (which we eventually map to an UpGuard node group).
  def pdb_get_role(facts)
    if facts.is_a?(Hash) && !facts['trusted'].nil? && !facts['trusted']['value'].nil? && !facts['trusted']['value']['extensions'].nil? && !facts['trusted']['value']['extensions']['pp_role'].nil?
      role = facts['trusted']['value']['extensions']['pp_role']
      Puppet.info("#{log_prefix} puppet role for node is: role=#{role}")
      role
    else
      "Unknown"
    end
  end

  # Extract out the environment (which we eventually map to an UpGuard environment).
  def pdb_get_environment(facts)
    if facts.is_a?(Hash) && !facts['trusted'].nil? && !facts['trusted']['value'].nil? && !facts['trusted']['value']['extensions'].nil? && !facts['trusted']['value']['extensions']['pp_environment'].nil?
      environment = facts['trusted']['value']['extensions']['pp_environment']
      Puppet.info("#{log_prefix} puppet environment for node is: environment=#{environment}")
      environment
    else
      "Unknown"
    end
  end

  # Extract out the datacenter (which we eventually map to an UpGuard node group).
  def pdb_get_datacenter(facts)
    if facts.is_a?(Hash) && !facts['trusted'].nil? && !facts['trusted']['value'].nil? && !facts['trusted']['value']['extensions'].nil? && !facts['trusted']['value']['extensions']['pp_datacenter'].nil?
      datacenter = facts['trusted']['value']['extensions']['pp_datacenter']
      Puppet.info("#{log_prefix} puppet datacenter for node is: datacenter=#{datacenter}")
      datacenter
    else
      "Unknown"
    end
  end

  # Get the node OS.
  def pdb_get_os(facts)
    if facts.is_a?(Hash) && !facts['operatingsystem'].nil? && !facts['operatingsystem']['value'].nil?
      os = facts['operatingsystem']['value']
      Puppet.info("#{log_prefix} puppet os for node is: os=#{os}")
      if os.downcase == 'windows'
        os = 'Windows'
      elsif os.downcase == 'centos'
        os = 'CentOS'
      end

      Puppet.info("#{log_prefix} fiendly puppet os for node is: os=#{os}")
      os
    else
      "Unknown"
    end
  end

  # Get the node OS major release version.
  def pdb_get_os_major_release(facts)
    if facts.is_a?(Hash) && !facts['operatingsystemmajrelease'].nil? && !facts['operatingsystemmajrelease']['value'].nil?
      os_major_release = facts['operatingsystemmajrelease']['value']
      Puppet.info("#{log_prefix} puppet os major release for node is: os major release=#{os_major_release}")
      os_major_release
    else
      "Unknown"
    end
  end

  def pdb_get_virt_platform(facts)
    if facts.is_a?(Hash) && !facts['virtual'].nil? && !facts['virtual']['value'].nil?
      virtual = facts['virtual']['value']
      Puppet.info("#{log_prefix} puppet virtualization platform for node is: virtual=#{virtual}")
      if virtual == 'physical'
        virtual = 'Baremetal'
      elsif virtual == 'xen'
        virtual = 'AWS'
      elsif virtual == 'vmware'
        # VMware the the "default", don't display anything for it.
        virtual = ''
      end

      Puppet.info("#{log_prefix} friendly virtualization platform for node is: virtual=#{virtual}")
      virtual
    else
      "Unknown"
    end
  end

  # Work out what Puppet files made the "change". We use this to tag the node scan in UpGuard.
  def pdb_manifest_files(logs)
    if test_env
      manifest_filename = "test node scan"
      manifest_filename = ERB::Util.url_encode(manifest_filename)
      Puppet.info("#{log_prefix} manifest_filename=#{manifest_filename}")
      return manifest_filename
    end

    manifest_filename = []
    default = ERB::Util.url_encode("puppet run")

    if logs && logs.any?
      (logs).each do |log|
        # Puppet.info("#{log_prefix} log: #{log}")
        if log.file
          # Puppet.info("#{log_prefix} log.file: #{log.file}")
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
      manifest_filename = ERB::Util.url_encode(manifest_filename.join(", ").slice(0..40))
    else
      manifest_filename = "#{default}"
    end

    Puppet.info("#{log_prefix} manifest_filename=#{manifest_filename}")
    manifest_filename
  end

  #############################################################################
  # UPGUARD METHODS                                                           #
  #############################################################################

  # Add the node to the node group.
  def upguard_add_to_node_group(node_id, node_group_id)
    Puppet.info("#{log_prefix} adding node_id=#{node_id} to node_group_id=#{node_group_id}")
    response = `curl -X POST #{UPGUARD_CURL_FLAGS} #{APPLIANCE_URL}/api/v2/node_groups/#{node_group_id}/add_node.json?node_id=#{node_id}`
    Puppet.info("#{log_prefix} add_to_node_group response=#{response}")
    JSON.load(response)
  end
  module_function :upguard_add_to_node_group

  # Add the node to the environment. We do this by updating the node rather than using an add_node endpoint.
  def upguard_add_to_environment(node_id, environment_id)
    Puppet.info("#{log_prefix} adding node_id=#{node_id} to environment_id=#{environment_id}")
    response = `curl -X PUT #{UPGUARD_CURL_FLAGS} -d '{ "node": { "environment_id": "#{environment_id}", "description": "#{VERSION_TAG}" }}' #{APPLIANCE_URL}/api/v2/nodes/#{node_id}`
    Puppet.info("#{log_prefix} add_to_environment response=#{response}")
  end
  module_function :upguard_add_to_environment

  # Check to see if the node has already been added to UpGuard. If so, return it's node_id.
  def upguard_node_lookup(external_id)
    response = `curl -X GET #{UPGUARD_CURL_FLAGS} #{APPLIANCE_URL}/api/v2/nodes/lookup.json?external_id=#{external_id}`
    Puppet.info("#{log_prefix} node_lookup response=#{response}")
    JSON.load(response)
  end
  module_function :upguard_node_lookup

  # We create UpGuard node groups to map to Puppet roles
  def upguard_node_group_create(node_group_name, node_group_rule)
    create_response = `curl -X POST #{UPGUARD_CURL_FLAGS} -d '{ "node_group": { "name": "#{node_group_name}", "description": "#{VERSION_TAG}", "node_rules": "#{node_group_rule}" }}' #{APPLIANCE_URL}/api/v2/node_groups`
    Puppet.info("#{log_prefix} node_group_create response=#{create_response}")
    lookup_response = `curl -X GET #{UPGUARD_CURL_FLAGS} #{APPLIANCE_URL}/api/v2/node_groups/lookup.json?name=#{ERB::Util.url_encode(node_group_name)}`
    Puppet.info("#{log_prefix} node_group_lookup response=#{lookup_response}")
    lookup_json = JSON.load(lookup_response)
    if lookup_json && lookup_json['node_group_id']
      lookup_json['node_group_id']
    else
      nil
    end
  end
  module_function :upguard_node_group_create

  # We create UpGuard environments to map to Puppet environments
  def upguard_environment_create(environment_name)
    create_response = `curl -X POST #{UPGUARD_CURL_FLAGS} -d '{ "environment": { "name": "#{environment_name}", "short_description": "#{VERSION_TAG}" }}' #{APPLIANCE_URL}/api/v2/environments`
    Puppet.info("#{log_prefix} environment_create response=#{create_response}")
    lookup_response = `curl -X GET #{UPGUARD_CURL_FLAGS} #{APPLIANCE_URL}/api/v2/environments/lookup.json?name=#{ERB::Util.url_encode(environment_name)}`
    Puppet.info("#{log_prefix} environment_lookup response=#{lookup_response}")
    lookup_json = JSON.load(lookup_response)
    if lookup_json && lookup_json['environment_id']
      lookup_json['environment_id']
    else
      nil
    end
  end
  module_function :upguard_environment_create

  # Creates the node in UpGuard
  def upguard_node_create(ip_hostname, os, datacenter_name)
    domain_details = determine_domain_details(ip_hostname, os, datacenter_name)
    Puppet.info("#{log_prefix} node_create ip_hostname=#{ip_hostname}")
    Puppet.info("#{log_prefix} node_create os=#{os}")
    # Puppet.info("#{log_prefix} node_create cm group=#{domain_details}")

    node = {}
    node[:node] = {}
    node[:node][:name] = "#{ip_hostname}"
    node[:node][:external_id] = "#{ip_hostname}"
    if test_env && TEST_OS.downcase == 'windows'
      ip_hostname = TEST_WINDOWS_HOSTNAME
    elsif test_env && TEST_OS.downcase == 'centos'
      ip_hostname = TEST_LINUX_HOSTNAME
    end
    node[:node][:medium_hostname] = "#{ip_hostname}"
    node[:node][:short_description] = "#{VERSION_TAG}"
    node[:node][:connection_manager_group_id] = "#{domain_details['id']}"
    node[:node][:medium_username] = "#{domain_details['service_account']}"
    node[:node][:medium_password] = "#{domain_details['service_password']}"

    if os && os.downcase == 'windows'
      node[:node][:node_type] = "SV" # Server
      node[:node][:operating_system_family_id] = 1
      node[:node][:operating_system_id] = 125 # Windows 2012
      node[:node][:medium_type] = 7 # WinRM
      node[:node][:medium_port] = 5985
    elsif os && os.downcase == 'centos'
      node[:node][:node_type] = "SV"
      node[:node][:operating_system_family_id] = 2
      node[:node][:operating_system_id] = 231 # CentOS
      node[:node][:medium_type] = 3 # SSH
      node[:node][:medium_port] = 22
    else # Add the node as a network device...
      node[:node][:node_type] = "FW" # Firewall
      node[:node][:operating_system_family_id] = 7
      node[:node][:operating_system_id] = 731 # Cisco ASA
      node[:node][:medium_type] = 3 # SSH
      node[:node][:medium_port] = 22
    end

    request = "curl -X POST #{UPGUARD_CURL_FLAGS} -d '#{node.to_json}' #{APPLIANCE_URL}/api/v2/nodes"
    # Puppet.info("#{log_prefix} node_create request=#{request}")
    response = `#{request}`
    # Puppet.info("#{log_prefix} node_create response=#{response}")
    node = JSON.load(response)

    if node["id"]
      if os && os.downcase != 'windows' && os.downcase != 'centos'
        Puppet.info("#{log_prefix} adding node to unclassified node group")
        unclassified_resp = upguard_add_to_node_group(node["id"], UNKNOWN_OS_NODE_GROUP_ID)
        Puppet.info("#{log_prefix} adding node to unclassified node group response=#{unclassified_resp}")
      end

      node["id"]
    else
      Puppet.err("#{log_prefix} failed to create node: #{ip_hostname}")
      raise StandardError, "#{log_prefix} unable to create node: confirm node parameters are correct"
    end
  end
  module_function :upguard_node_create

  # Kick off a node scan
  def upguard_node_scan(node_id, tag)
    response = `curl -X POST #{UPGUARD_CURL_FLAGS} #{APPLIANCE_URL}/api/v2/nodes/#{node_id}/start_scan.json?label=#{tag}`
    Puppet.info("#{log_prefix} node_scan response=#{response}")
    JSON.load(response)
  end
  module_function :upguard_node_scan

  # Kick off a vulnerability scan
  def upguard_node_vuln_scan(node_id)
    response = `curl -X POST #{UPGUARD_CURL_FLAGS} '#{APPLIANCE_URL}/api/v2/jobs.json?type=node_vulns&vuln_limit=5000&vuln_severity=5&type_id=#{node_id}'`
    Puppet.info("#{log_prefix} node_vuln_scan response=#{response}")
    JSON.load(response)
  end
  module_function :upguard_node_vuln_scan
end
