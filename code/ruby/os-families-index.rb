require 'net/http'
require 'json'

uri = URI.join('http://localhost:3000', '/api/v1/operating_system_families.json')
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
      puts JSON.pretty_generate(JSON.load(data), {:indent => '  ',
        :space => ' '})
  else
      puts str(res.code) + res.message;
  end
end
