#!/usr/bin/ruby

require 'net/http'
require 'json'

api_key     = "<API_KEY>" 
secret_key  = "<SECRET_KEY>"

node = {
    :name => "host.com",
    :node_type => "SV",
    :medium_type => 3,
    :medium_username => "username",
    :medium_hostname => "hostname",
    :connection_manager_group_id => 1,
}

# NB: Swap in your custom URL here if you have a dedicated instance
uri = URI.join('https://guardrail.scriptrock.com', '/api/v1/nodes.json')
req = Net::HTTP::Get.new(uri)
req['Authorization'] = 'Token token="AB123456CDEF7890GH"'
req['Accept'] = 'application/json'
req['Content-Type'] = 'application/x-www-form-urlencoded'
req.body = node.map{|k, v| "node[#{k.to_s}]=#{v.to_s}"}.join('&')

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
