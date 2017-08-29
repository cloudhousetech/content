require 'httparty'
require 'vine'

# Clem: single ticket with full history
# 1. Create upguard-cv.lock file
# 1. inspect Policy Ran events since last run time
# 2. for each event, lookup job_id to get list of nodes to check
# 3. for each node, lookup if ticket exists in jira based on ticket label
      # next unless ticket exists
# 4.  # node, get latest policy_results
      # next if jira_status == latests_policy_results_status
      # add latest_policy_results as a comment to the ticket
      # update the ticket_status (Pass to Fail, Fail to Pass)


def main

  node_name = 'my-node-name'
  ug = UpGuard.new
  ug.get_jira_ticket(node_name)

  #ug.update_node(327)
  #ug.create_node_group('Orange') #78
  #ug.create_node_group('Second') #77
  #ug.add_node_to_node_group(327, 78)
  #ug.remove_node_from_node_group(327, 78)
  #ug.scan_node(327, "post_jenkins_deploy")
  #ug.scan_diff(28158, 28123)
end

class UpGuard

  @@file_name = File.basename(__FILE__)
  puts @file_name
  @@jira_hostname = 'https://my-jira.instance.net'
  @@jira_username = 'username@domain.com'
  @@jira_password = 'password'
  @@jira_project_id = 'project_id'






  #$api_key    = 'api_key'
  #$secret_key = 'secret_key'
  #$website    = 'https://my.appliance.url'

  # Endpoints
  #$nodes_index_endpoint                 = "#{$website}/api/v2/nodes"
  #$nodes_show_endpoint                  = "#{$website}/api/v2/nodes/{{id}}"
  #$nodes_scan_endpoint                  = "#{$website}/api/v2/nodes/{{id}}/start_scan?label={{label}}"
  #$node_add_to_node_group_endpoint      = "#{$website}/api/v2/nodes/{{id}}/add_to_node_group?node_group_id={{node_group_id}}"
  #$node_remove_from_node_group_endpoint = "#{$website}/api/v2/nodes/{{id}}/remove_from_node_group?node_group_id={{node_group_id}}"
  #$node_groups_index_endpoint           = "#{$website}/api/v2/node_groups"
  #$node_diff_endpoint                   = "#{$website}/api/v2/nodes/diff?scan_id={{scan_id}}&compare_scan_id={{compare_scan_id}}"

  def get_jira_ticket(node_name)
    begin
      # Filter on project first to speed up query.
      jql = ERB::Util.url_encode("project = #{@@jira_project_id} AND labels = #{node_name}")
      auth = { :username => "#{@@jira_username}", :password => "#{@@jira_password}" }
      response = HTTParty.get("#{@@jira_hostname}/rest/api/2/search?jql=#{jql}",
                               :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
                               :basic_auth => auth).to_hash
    rescue StandardError => e
      puts "FATAL: retrieving JIRA ticket: #{e}"
      exit
    end

    puts response
  end

  def create_node_group(name)

    node_group = {
        :node_group => {
            :name => name
        }
    }

    response = HTTParty.post($node_groups_index_endpoint,
                             :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\"" },
                             :body => node_group.to_json)

    puts response
  end

  def add_node_to_node_group(node_id, to_node_group)
    $node_add_to_node_group_endpoint.sub!('{{id}}', node_id.to_s)
    $node_add_to_node_group_endpoint.sub!('{{node_group_id}}', to_node_group.to_s)

    response = HTTParty.post($node_add_to_node_group_endpoint,
                             :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\"" })

    puts response
  end

  def remove_node_from_node_group(node_id, to_node_group)
    $node_remove_from_node_group_endpoint.sub!('{{id}}', node_id.to_s)
    $node_remove_from_node_group_endpoint.sub!('{{node_group_id}}', to_node_group.to_s)

    response = HTTParty.post($node_remove_from_node_group_endpoint,
                             :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\"" })

    puts response
  end

  def update_node(node_id)
    $nodes_show_endpoint.sub!('{{id}}', node_id.to_s)
    node = {
        :node => {
            :name => 'MTV-TEST-11',
            :external_id => 'MTV-TEST-11',
            # :short_description => 'Added via api-demo.rb v1.0',
            # :node_type => 'SV',
            # :medium_type => 3,
            # :medium_hostname => '10.0.6.183',
            # :medium_port => 22,
            # :medium_username => 'centos',
            # :operating_system_family_id => 7,
            # :operating_system_id => 731,
            # :connection_manager_group_id => 1
        }
    }

    response = HTTParty.put($nodes_show_endpoint,
                             :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\"" },
                             :body => node.to_json)
    puts response

  end

  def scan_node(node_id, label)
    $nodes_scan_endpoint.sub!('{{id}}', node_id.to_s)
    $nodes_scan_endpoint.sub!('{{label}}', label)

    response = HTTParty.post($nodes_scan_endpoint,
                             :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\"" })

    puts response
  end

  def scan_diff(scan_id, compare_scan_id)
    $node_diff_endpoint.sub!('{{scan_id}}', scan_id.to_s)
    $node_diff_endpoint.sub!('{{compare_scan_id}}', compare_scan_id.to_s)

    response = HTTParty.get($node_diff_endpoint,
                             :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\"" })

    puts response
  end

end

main

