require "httparty"

@sr_api_key         = ""
@sr_secret_key      = ""
@sr_url             = "https://app.upguard.com"
@headers            = { "Authorization" => "Token token=\"#{@sr_api_key}#{@sr_secret_key}\"" }

def get_all_environments
  puts "Getting Environments"
  puts "---------------------"
  
  # Get all nodes
  page     = 1
  per_page = 1000
  response = HTTParty.get(
    "#{@sr_url}/api/v2/environments.json?page=#{page}&per_page=#{per_page}",
    :headers => @headers
  )

  if response.code.to_s == "200"
    envs = JSON.parse(response.body)
    envs.each do |env|
      puts "Found env #{env["name"]} (#{env["id"]})"
    end
  elsif response.code.to_s != "404"
    puts "Failed to get envs with code #{response.code} #{response.message}"
  end
  
  puts ""
end

def get_all_nodes
  puts "Getting All Nodes"
  puts "---------------------"  
  
  # Get all nodes
  page     = 1
  per_page = 1000
  response = HTTParty.get(
    "#{@sr_url}/api/v2/nodes.json?page=#{page}&per_page=#{per_page}",
    :headers => @headers
  )

  if response.code.to_s == "200"
    nodes = JSON.parse(response.body)
    nodes.each do |node|
      puts "Found node #{node["name"]} (#{node["id"]})"
      get_node_groups_for_node(node["name"], node["id"])
    end
  elsif response.code.to_s != "404"
    puts "Failed to get nodes with code #{response.code} #{response.message}"
  end
  
  puts ""
end

def get_all_node_groups
  puts "Getting All Node Groups"
  puts "---------------------"  
  
  # Get all nodes
  page     = 1
  per_page = 1000
  response = HTTParty.get(
    "#{@sr_url}/api/v2/node_groups.json?page=#{page}&per_page=#{per_page}",
    :headers => @headers
  )

  if response.code.to_s == "200"
    node_groups = JSON.parse(response.body)
    node_groups.each do |node_group|
      puts "Found node group #{node_group["name"]} (#{node_group["id"]})"
    end
  elsif response.code.to_s != "404"
    puts "Failed to get node groups with code #{response.code} #{response.message}"
  end
  
  puts ""
end

def update_node(node_id, data)
  puts "Updating node #{node_id}"
  response = HTTParty.put("#{@sr_url}/api/v2/nodes/#{node_id}.json",
    :headers => @headers,
    :body    => data
  )

  if response.code == 204
    puts "  Successfully updated node #{node_id}"
  else
    puts "  Failed to update node #{node_id} with error code #{response.code} #{response.body}"
  end    
end

def add_node_to_group(node_id, node_group_id)
  puts "Adding node #{node_id} to group #{node_group_id}"
  response = HTTParty.post("#{@sr_url}/api/v2/nodes/#{node_id}/add_to_node_group.json?node_group_id=#{node_group_id}",
      :headers => @headers
  )
  
  if response.code == 201
    puts "  Successfully added node #{node_id} to group #{node_group_id}"
  else
    puts "  Failed to add node #{node_id} to group #{node_group_id} with error code #{response.code} #{response.body}"
  end  
end

def remove_node_from_group(node_id, node_group_id)
  puts "Removing node #{node_id} to group #{node_group_id}"
  response = HTTParty.post("#{@sr_url}/api/v2/nodes/#{node_id}/remove_from_node_group.json?node_group_id=#{node_group_id}",
      :headers => @headers
  )
  
  if response.code == 204
    puts "  Successfully removed node #{node_id} from group #{node_group_id}"
  else
    puts "  Failed to remove node #{node_id} from group #{node_group_id} with error code #{response.code} #{response.body}"
  end
end

def get_node_groups_for_node(node_name, node_id)
  puts "Getting node groups for node #{node_name} (#{node_id})"
  
  # Get node groups
  response = HTTParty.get(
    "#{@sr_url}/api/v2/nodes/#{node_id}/node_groups.json",
    :headers => @headers
  )
  node_groups = JSON.parse(response.body)
  node_groups.each do |node_group|
    puts "  - in node group #{node_group["name"]}"
  end
end

# data =  {
#           "node": {
#               "environment_id": 2
#           }
#         }
# update_node(99999, data)

# add_node_to_group(999999, 777777)

# remove_node_from_group(9999999, 777777)

get_all_node_groups

get_all_environments

get_all_nodes

get_node_groups_for_node
