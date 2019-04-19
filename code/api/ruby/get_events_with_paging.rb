require 'active_support/all'
require "httparty"

@website    = "https://<YOUR_SITE>"
@api_key    = <API_KEY>
@secret_key = <SECRET_KEY>
@headers    = { "Authorization" => "Token token=\"#{@api_key}#{@secret_key}\"" }
page        = 1
per_page    = 500
events      = nil
total       = 0
all_events  = []

# Set fixed parts of the URL
url         = "#{@website}/api/v2/events.json?view_name=All&per_page=#{per_page}&date_from=10 days ago"

while events.nil? || events.count == per_page
  puts "  Retrieving page #{page} of events for view with url #{url}&page=#{page}"
  events  = HTTParty.get("#{url}&page=#{page}", :headers => @headers)

  if events.response.code.to_i != 200
    puts "  ERROR trying to retrieve events:"
    puts "    #{events.body}"
    next
  end

  puts "  Retrieved #{events.count} events"
  all_events += events
  page       += 1
end

# Loop through all events
all_events.each do |event|
  puts event
end
