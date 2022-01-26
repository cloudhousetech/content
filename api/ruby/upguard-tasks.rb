require 'httparty'

def main
  ug = UpGuard.new

  # This method is used to update the username and password for nodes belonging to a particular connection
  # manager group and operating system family.
  # node_username = 'username'
  # node_password = 'password'
  # cm_group_id   = 123
  # os_family     = 'windows'
  # ug.update_creds_per_cmg_and_osf(node_username, node_password, cm_group_id, os_family)

  # This method will remove nodes of a particular operating system from a node group.
  # E.g. Remove all Windows 2008 nodes from the "Windows Mixed" node group as this group
  # should only container Windows 2012 nodes.
  # os_id = 125 # 125 = Windows 2012, 123 = Windows 2008,
  # node_group_id = 83
  # ug.remove_os_from_node_group(os_id, node_group_id)
end

class UpGuard

  $version     = '0.0.3'
  $test_mode   = true
  $script_name = 'upguard'
  $api_key     = 'YOUR API KEY'
  $secret_key  = 'YOUR SECRET KEY'
  $website     = 'https://YOUR.UPGUARD.INSTANCE'
  $verify_ssl  = false
  $headers     = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\""
  }

  # Endpoints
  @nodes_index_endpoint = "#{$website}/api/v2/nodes?page={{page_number}}&per_page={{per_page_number}}"
  @nodes_show_endpoint  = "#{$website}/api/v2/nodes/{{id}}"
  @nodes_remove_node_group = "#{$website}/api/v2/nodes/{{node_id}}/remove_from_node_group.json?node_group_id={{node_group_id}}"
  @node_group_nodes_endpoint = "#{$website}/api/v2/node_groups/{{node_group_id}}/nodes.json?page={{page_number}}&per_page={{per_page_number}}"

  class << self
    attr_accessor :nodes_index_endpoint, :nodes_show_endpoint, :node_group_nodes_endpoint, :nodes_remove_node_group
  end

  def remove_os_from_node_group(os_id, node_group_id)
    page = 1
    all_nodes = []
    found_no_nodes = true

    some_nodes = get_more_node_group_nodes(node_group_id, page)
    all_nodes += some_nodes
    while !some_nodes.nil? && some_nodes.any?
      page += 1
      some_nodes = get_more_node_group_nodes(node_group_id, page)
      all_nodes += some_nodes
    end

    all_nodes.each do |node|
      working_url = UpGuard.nodes_show_endpoint.sub('{{id}}', node['id'].to_s)
      response = Client.get(working_url)
      node_detail = JSON.load(response.body)
      if node_detail['operating_system_id'] == os_id
        found_no_nodes = false
        if $test_mode
          puts "#{log_prefix} would remove #{node['name']}"
          next
        else
          working_url = UpGuard.nodes_remove_node_group.sub('{{node_id}}', node['id'].to_s)
          working_url = working_url.sub('{{node_group_id}}', node_group_id.to_s)
          response = Client.post(working_url)
          puts "#{log_prefix} removed #{node['name']}: '#{response.body}'"
        end
      end
    end

    if found_no_nodes
      puts "#{log_prefix} no nodes found to remove"
    end
  end

  def update_creds_per_cmg_and_osf(username, password, cmg_id, osf_name)
    page = 1
    all_nodes = []
    found_no_nodes = true

    some_nodes = get_more_nodes(page)
    all_nodes += some_nodes
    while !some_nodes.nil? && some_nodes.any?
      page += 1
      some_nodes = get_more_nodes(page)
      all_nodes += some_nodes
    end

    all_nodes.each do |node|
      working_url = UpGuard.nodes_show_endpoint.sub('{{id}}', node['id'].to_s)
      # Need to make an additional call to the node show endpoint to get CM group id
      response = Client.get(working_url)
      node = JSON.load(response.body)
      if node['connection_manager_group_id'] == cmg_id && node['operating_system_family_id'] == os_family_to_id(osf_name)
        found_no_nodes = false

        if $test_mode
          puts "#{log_prefix} would update #{node['name']}"
          next
        else
          payload = {
              :node => {
                  :medium_username => "#{username}",
                  :medium_password => "#{password}",
                  :connection_manager_group_id => cmg_id
              }
          }

          # Update creds
          response = Client.put(working_url, :body => payload.to_json)
          puts "#{log_prefix} updated #{node['name']}: '#{response.body}'"
        end
      end
    end

    if found_no_nodes
      puts "#{log_prefix} no nodes found to update"
    end
  end

  def log_prefix
    if $test_mode
      "#{$script_name}: [TEST MODE]"
    else
      "#{$script_name}:"
    end
  end

  def os_family_to_id(osf_name)
    if osf_name == 'windows'
      1
    else
      2
    end
  end

  def get_more_nodes(page)
    per_page = 50
    working_url = UpGuard.nodes_index_endpoint.sub('{{page_number}}', page.to_s)
    working_url = working_url.sub('{{per_page_number}}', per_page.to_s)
    response = Client.get(working_url)
    JSON.parse(response.body)
  end

  def get_more_node_group_nodes(node_group_id, page)
    per_page = 50
    working_url = UpGuard.node_group_nodes_endpoint.sub('{{page_number}}', page.to_s)
    working_url = working_url.sub('{{per_page_number}}', per_page.to_s)
    working_url = working_url.sub('{{node_group_id}}', node_group_id.to_s)
    response = Client.get(working_url)
    JSON.parse(response.body)
  end
end

class Client
  include HTTParty

  default_options.update(verify: $verify_ssl)
  default_options.update(headers: $headers)
end

main

