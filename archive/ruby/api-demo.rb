require 'httparty'
require 'vine'

def main

  node = {
      :node => {
          :name => 'MTV-TEST-010',
          :external_id => 'MTV-TEST-10',
          :short_description => 'Added via api-demo.rb v1.0',
          :node_type => 'SV',
          :medium_type => 3,
          :medium_hostname => '10.0.6.183',
          :medium_port => 22,
          :medium_username => 'centos',
          :operating_system_family_id => 2,
          :operating_system_id => 231,
          :connection_manager_group_id => 1
      }
  }

  ug = UpGuard.new
  ug.create_node(node)
  #ug.update_node(327)
  #ug.create_node_group('Orange') #78
  #ug.create_node_group('Second') #77
  #ug.add_node_to_node_group(327, 78)
  #ug.remove_node_from_node_group(327, 78)
  #ug.scan_node(327, "post_jenkins_deploy")
  #ug.scan_diff(28158, 28123)
end

class UpGuard

  $api_key    = 'api_key'
  $secret_key = 'secret_key'
  $website    = 'https://my.appliance.url'

  # Endpoints
  $nodes_index_endpoint                 = "#{$website}/api/v2/nodes"
  $nodes_show_endpoint                  = "#{$website}/api/v2/nodes/{{id}}"
  $nodes_scan_endpoint                  = "#{$website}/api/v2/nodes/{{id}}/start_scan?label={{label}}"
  $node_add_to_node_group_endpoint      = "#{$website}/api/v2/nodes/{{id}}/add_to_node_group?node_group_id={{node_group_id}}"
  $node_remove_from_node_group_endpoint = "#{$website}/api/v2/nodes/{{id}}/remove_from_node_group?node_group_id={{node_group_id}}"
  $node_groups_index_endpoint           = "#{$website}/api/v2/node_groups"
  $node_diff_endpoint                   = "#{$website}/api/v2/nodes/diff?scan_id={{scan_id}}&compare_scan_id={{compare_scan_id}}"

  def create_node(node)
    response = HTTParty.post($nodes_index_endpoint,
                             :headers  => { 'Content-Type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{$api_key}#{$secret_key}\"" },
                             :body => node.to_json)
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

