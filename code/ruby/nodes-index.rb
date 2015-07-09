@nodes = []

while true
  
  page += 1
  puts "Getting page #{page}"
  
  response = HTTParty.get(
    "https://guardrail.scriptrock.com/api/v1/nodes.json?page=#{page}&per_page=#{per_page}",
    :headers => { "Authorization" => "Token token=\"#{api_key}#{secret_key}\"",
                  'Accept' => 'application/json' }
  )

  if response.code.to_s == "200"
    node_array = JSON.parse(response.body)
    @nodes << node_array
    if node_array.size < per_page
      break
    end
  elsif response.code.to_s != "404"
    puts "Error getting nodes: http code=#{response.code}"
  end
  
end
