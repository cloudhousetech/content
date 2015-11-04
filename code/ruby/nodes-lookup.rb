require 'net/http'
require 'json'

api_key = 'api key here'
secret_key = 'secret key here'
url = 'appliance.url.here'

uri = URI.join('https://' + url,
'/api/v1/nodes/42/add_to_node_group.json?node_group_id=23')
req = Net::HTTP::Get.new(uri)
req['Authorization'] = 'Token token="' + api_key + secret_key + '"'
req['Accept'] = 'application/json'

Net::HTTP::start(uri.host, uri.port) do |http|
  res = http.request(req)
  data = res.body

  if Integer(res.code) >= 400
      raise res.code + ' ' + res.message + (data.strip() == '' ?
        ': ' + data.strip() : '')
  end

  if data != ''
      return JSON.pretty_generate(JSON.load(data), {:indent => '  ',
        :space => ' '})
  else
      return str(res.code) + res.message;
  end
end