#!/usr/bin/ruby

require 'net/http'
require 'json'
require 'csv'

def add_node(node)
  uri = URI.join('http://localhost:3000', '/api/v1/nodes.json')
  req = Net::HTTP::Post.new(uri)

  req.body = node.map{|k, v| "node[#{k.to_s}]=#{v.to_s}"}.join('&')

  req['Authorization'] = 'Token token="ABCD123456EF7890GH"'
  req['Content-Type'] = 'application/x-www-form-urlencoded'

  Net::HTTP::start(uri.host, uri.port) do |http|
    res = http.request(req)

    data = res.body

    if Integer(res.code) >= 400
        raise res.code + ' ' + res.message + (data.strip() == '' ? ': ' +
            data.strip() : '')
    end

    if data != ''
        return JSON.pretty_generate(JSON.load(data), {:indent => '  ', :space => ' '})
    else
        return str(res.code) + res.message;
    end
  end
end

CSV.foreach('nodes.csv') do |row|
  node = {
      :name => row[0],
      :node_type => row[1],
      :medium_type => row[2],
      :medium_username => row[3],
      :medium_password => row[4],
      :connection_manager_group_id => row[5]
  }
  add_node(node)
end
