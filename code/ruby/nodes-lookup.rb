

NEEDS TO BE CHANGED BEFORE ADDING TO DOCS SITE


require 'net/http'
require 'json'

uri = URI.join('http://localhost:3000',
'/api/v1/nodes/42/add_to_node_group.json?node_group_id=23')
req = Net::HTTP::Get.new(uri)
req['Authorization'] = 'Token token="AB123456CDEF7890GH"'
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