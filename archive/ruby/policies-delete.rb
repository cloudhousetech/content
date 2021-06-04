#!/usr/bin/ruby

require 'net/http'
require 'json'

def main

    policies = []
    policies_whitelist = [1389, 1263, 1320, 1267, 1345, 1337, 1316, 1344, 1408]

    # Grab all policies
    sr = ScriptRock.new
    all_policies = sr.get_policies
    all_policies.each do |p|
        policies.push(p["id"])
    end 

    # Nicely display all policies
    puts JSON.pretty_generate(all_policies, {:indent => '  ', :space => ' '})
 
    # Remove from this the nodes we have whitelisted
    policies_whitelist.each do |w|
        if policies.index(w)
            policies.delete_at(policies.index(w))
        else
            puts "Looks like policy id #{w} (from whitelist) has been deleted by someone"
        end
    end    

    # Delete!
    sr.delete_policies(policies)

end    

class ScriptRock

    $api_key = '<<< API_KEY >>>' 
    $secret_key = '<<< SECRET_KEY >>>'
    $website = 'https://guardrail.scriptrock.com'
    $policies_index_api = '/api/v1/policies'

    def delete_policies(policies)

        policies.each do |p|

            uri = URI.join($website, "#{$policies_index_api}/#{p}")
            req = Net::HTTP::Delete.new(uri)
            req['Authorization'] = "Token token=\"#{$api_key}#{$secret_key}\""
            req['Accept']        = 'application/json'
            req['Content-Type']  = 'application/x-www-form-urlencoded'
    
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == "https")

            res = http.request(req)
            data = res.body

            if Integer(res.code) >= 400
                raise res.code + ' ' + res.message + (data.strip() == '' ? ': ' + data.strip() : '')
            elsif Integer(res.code) == 204
                puts "Deleted policy id: #{p}"
            end
        end       
    end    

    def get_policies

        uri = URI.join($website, $policies_index_api, '?page=1&per_page=50')
        req = Net::HTTP::Get.new(uri)
        req['Authorization'] = "Token token=\"#{$api_key}#{$secret_key}\""
        req['Accept']        = 'application/json'
        req['Content-Type']  = 'application/x-www-form-urlencoded'
    
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")

        res = http.request(req)
        data = res.body

        if Integer(res.code) >= 400
            raise res.code + ' ' + res.message + (data.strip() == '' ? ': ' + data.strip() : '')
        end

        if data != ''
            return JSON.parse(data)
            #puts JSON.pretty_generate(JSON.load(data), {:indent => '  ', :space => ' '})
        else
            puts res.code + res.message;
        end
    end
end       

main
