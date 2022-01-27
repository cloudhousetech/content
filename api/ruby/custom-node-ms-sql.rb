#!/usr/bin/ruby

require 'tiny_tds'
require 'json'

table = {}
columns = {}

client = TinyTds::Client.new username: '', password: '', host: '', port: 1433, database: ''
result = client.execute("select * from sys.databases where name = ''")

result.each do |row|
  row.to_hash
  row.each do |column_name, column_value|
    set = {}
    set['value'] = column_value
    columns[column_name] = set
  end
end

table['settings'] = columns
puts table.to_json
