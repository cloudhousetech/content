#!/usr/bin/ruby

require 'net/http'
require 'json'

api_key = '<<< API KEY >>>'
secret_key = '<<< SECRET KEY >>>'
url = 'https://app.upguard.com'
node_id = 2458
policy_id = 2116

uri = URI.join(url, "/api/v2/policies/#{policy_id}/latest_results.json")
req = Net::HTTP::Get.new(uri)
req['Authorization'] = 'Token token="' + api_key + secret_key + '"'
req['Accept'] = 'application/json'

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = (uri.port == 443)

res = http.request(req)
data = res.body

if Integer(res.code) >= 400
	raise res.code + ' ' + res.message + (data.strip() == '' ? ': ' + data.strip() : '')
end

if data != ''
  response = JSON.load(data)
  response['policy_stats'].each do |stat|
  	if stat['node_id'].to_i == node_id
		if stat['fail_count'].to_i == 0
			puts "node is passing all policy tests"
		elsif
			puts "node is failing policy tests"
		end	
	end
  end
else
  return str(res.code) + res.message;
end
