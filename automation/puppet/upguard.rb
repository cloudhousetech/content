require 'puppet'
require 'json'
require 'erb'

Puppet::Reports.register_report(:upguard) do

  VERSION = "v1.5.6"
  CONFIG_FILE_NAME = "upguard.yaml"
  VERSION_TAG = "Added by #{File.basename(__FILE__)} #{VERSION}"
  desc "Create a node (if not present) and kick off a node scan in UpGuard if changes were made."

  configfile = File.join([File.dirname(Puppet.settings[:config]), CONFIG_FILE_NAME])
  raise(Puppet::ParseError, "#{CONFIG_FILE_NAME} config file #{configfile} not readable") unless File.exist?(configfile)
  begin
    config = YAML.load_file(configfile)
  rescue TypeError
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
  HTTP_TIMEOUTS            = config[:http_timeouts] || 20
  UPGUARD_CURL_FLAGS       = "--connect-timeout #{HTTP_TIMEOUTS} --max-time #{HTTP_TIMEOUTS} -s -k -H 'Authorization: Token token=\"#{API_KEY}\"' -H 'Accept: application/json' -H 'Content-Type: application/json'"

  def process
    Puppet.info("#{log_prefix} starting report processor #{VERSION}")

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

    ##########################################################################
    # PUPPET DB (PDB) METHODS                                                #
    ##########################################################################

    # Create a hash to store the PDB info we need.
    puppet_run = {}

    # Get the node name
    puppet_run['node_ip_hostname'] = pdb_get_hostname(self.host)
    if puppet_run['node_ip_hostname'].include?(IGNORE_HOSTNAME_INCLUDE)
      Puppet.info("#{log_prefix} returning early, '#{puppet_run['node_ip_hostname']}' includes '#{IGNORE_HOSTNAME_INCLUDE}'")
      return
    end

    # We use this to tag node scans with the puppet "file(s)" that have caused the change
    puppet_run['manifest_filename'] = pdb_manifest_files(self.logs)
    # Get trusted facts from the Puppet DB once
    facts = pdb_get_facts(puppet_run['node_ip_hostname'])
    # Get the operating system
    puppet_run['os'] = pdb_get_os(facts)
    puppet_run['os_version'] = pdb_get_os_major_release(facts)
    # Extract the role, environment and datacenter
    puppet_run['node_group_name'] = pdb_get_role(facts)
    puppet_run['environment_name'] = pdb_get_environment(facts)
    puppet_run['datacenter_name'] = pdb_get_datacenter(facts)
    # The format for environment names is datacenter_environment
    puppet_run['environment_name'] = generate_environment_name(puppet_run['datacenter_name'], puppet_run['environment_name'])
    # Is the node on baremetal, AWS or VMware?
    puppet_run['virt_platform'] = pdb_get_virt_platform(facts)

    ##########################################################################
    # DRIVER METHODS                                                         #
    ##########################################################################

    # Send details to a file for asynchronous processing
    Puppet.info("#{log_prefix} #########################################")
    Puppet.info("#{log_prefix} #       OPERATING IN OFFLINE MODE       #")
    Puppet.info("#{log_prefix} #########################################")
    # Let the user know that this scan was done from offline mode.
    hostname = "#{`hostname`}".strip
    puppet_run['manifest_filename'] += ERB::Util.url_encode(" (offline mode, processed by #{hostname})")
    store_puppet_run(OFFLINE_MODE_FILENAME, puppet_run)
    Puppet.info("#{log_prefix} returning early, '#{APPLIANCE_URL}' is offline")
  
  ##############################################################################
  # DRIVER METHODS                                                             #
  ##############################################################################

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

end
