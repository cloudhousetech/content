#
# This script iterates through views defined in the config file, aggregating events by view/node,
# and then making single calls to JIRA (either to add or update tickets)
# It assumes that the view has an existing JIRA action, and uses the details from that action for the JIRA calls.
# Below is an example of the config file it requires (events_config.yml)
# NB: If helper variables are used by the event action (variables not in the events), you need to specify them in config
#
# There are variables at the top of the script that allow you to output the generated ticket to jira, to a file, or both
# 
# ---------------------------------------------------------------------------------------------------
# EXAMPLE events_config.yml
# Copy lines 13-27 to file in same folder as script, uncomment, and update values, before running
# ---------------------------------------------------------------------------------------------------
#
# ---
# UPGUARD_WEBSITE: https://demo.upguard.com
# UPGUARD_API_KEY: 12323b13bf1323d12e32131a312312a1321a312
# UPGUARD_SECRET_KEY: 22323b13bf1323d12e32131a312312a1321a312
# EVENT_VIEWS:
# - View name 1
# - View name 2
# View_name_1_last_processed_id: 20175357 # Get last ID with MetricsView.find(10).metrics.first.first
# View_name_2_last_processed_id: 20176663
# HELPER_VARIABLES:
# - node_url
# - instance_hostname
# JIRA_URL: https://myco.atlassian.net
# JIRA_USERNAME: joe@test.com
# JIRA_PASSWORD: joes_good_pwd
#
#


require 'active_support/all'
require "httparty"
require "rest_client"

@config         = YAML.load_file(File.expand_path('events_config.yml'))
@website        = @config["UPGUARD_WEBSITE"]
@api_key        = @config["UPGUARD_API_KEY"]
@secret_key     = @config["UPGUARD_SECRET_KEY"]
@headers        = { "Authorization" => "Token token=\"#{@api_key}#{@secret_key}\"" }
@jira_auth      = { :username => @config["JIRA_USERNAME"], :password => @config["JIRA_PASSWORD"] }
@logs           = []
@stdout         = true
@event_data     = {}
@event			= {}
@view_totals    = {}
@lookup_fields  = true
@event_actions  = {}
@projects       = {}
@issue_types    = {}
@priorities     = {}
@timeout        = 300
@to_jira        = true
@to_file        = true
@to_directory   = "upguard"

def log(message)
  puts message if @stdout
  File.open("events.log", 'a') { |file| file.write("#{DateTime.now}: #{message}\n") }
end

def lookup_field_ids()
  log "-----------------------------------------------" if @lookup_fields
  log "Looking up fields"                               if @lookup_fields
  log "-----------------------------------------------" if @lookup_fields
  log "Projects:"                                       if @lookup_fields
  endpoint  = "#{@config["JIRA_URL"]}/rest/api/2/project"
  response = HTTParty.get(endpoint,
                            :headers    => { "Content-Type" => "application/json", "Accept" => "application/json" },
                            :basic_auth => @jira_auth,
                            :verify     => false)

  # log response
  response.each do |project|
    log "#{project["id"]} -  #{project["name"]}" if @lookup_fields
    @projects[project["id"]] = project["name"]
  end

  log ""               if @lookup_fields
  log "Issue Types:"   if @lookup_fields
  endpoint  = "#{@config["JIRA_URL"]}/rest/api/2/issuetype"
  response = HTTParty.get(endpoint,
                            :headers    => { "Content-Type" => "application/json" },
                            :basic_auth => @jira_auth,
                            :verify     => false)

  response.each do |type|
    log "#{type["id"]} -  #{type["name"]}" if @lookup_fields
    @issue_types[type["id"]] = type["name"]
  end

  log ""          if @lookup_fields
  log "Priority:" if @lookup_fields
  endpoint  = "#{@config["JIRA_URL"]}/rest/api/2/priority"
  response = HTTParty.get(endpoint,
                            :headers    => { "Content-Type" => "application/json" },
                            :basic_auth => @jira_auth,
                            :verify     => false)

  response.each do |priority|
    log "#{priority["id"]} -  #{priority["name"]}" if @lookup_fields
    @priorities[priority["id"]] = priority["name"]
  end
end

def build_event_hash(event)
  {
    "id"        => event["id"],
    "action"    => event["variables"]["action"],
    "path"      => event["variables"]["path"],
    "username"  => event["variables"]["username"],
    "timestamp" => event["variables"]["timestamp"]
  }
end

def gather_event_actions()
  log "Retrieving event actions..."
  event_actions  = HTTParty.get("#{@website}/api/v2/event_actions.json?page=1&per_page=1000", :headers => @headers, :verify => false)
  log event_actions

  # Filter for JIRA actions only
  event_actions = event_actions.select { |e| e["type"] == "jira" }
  log "  Found #{event_actions.count} JIRA event actions"

  event_actions.each do |action|
    @event_actions[action["view"]] = action
  end
end

def gather_events()
  @config["EVENT_VIEWS"].each do |view|
    log "Processing #{view} view"
    log "#{view.upcase.gsub(/\s/, "_")}_last_processed_id"

    # Check to see if we have a last_processed_id
    last_processed_id = @config["#{view.upcase.gsub(/\s/, "_")}_last_processed_id"].to_i

    if last_processed_id > 0
      log "  Found last processed event ID of #{last_processed_id}"
    else
      log "  No last processed event ID found"
      last_processed_id = nil
    end

    #
    # TEST ONLY!!!
    # last_processed_id = nil

    # Get the view's events
    page        = 1
    per_page    = 500
    events      = nil
    total       = 0

    # Set fixed parts of the URL
    url     = "#{@website}/api/v2/events.json?view_name=#{view}&per_page=#{per_page}"
    url    += "&last_event_id=#{last_processed_id}"                         if last_processed_id
    url    += "&helper_variables=#{@config["HELPER_VARIABLES"].join(",")}"  if @config["HELPER_VARIABLES"] && @config["HELPER_VARIABLES"].any?

    while events.nil? || events.count == per_page
      log "  Retrieving page #{page} of events for view with url:\n    #{url}&page=#{page}..."
      events  = HTTParty.get("#{url}&page=#{page}", :headers => @headers, :verify => false, :timeout => @timeout)

      if events.response.code.to_i != 200
        log "  ERROR trying to retrieve events:"
        log "    #{JSON.parse(events.body)}"
        next
      end

      log "  Retrieved #{events.count} events"

      # Cycle through and aggregate event data by node
      events.each do |event|
        # puts event["id"]
        @event_data[view]                       ||= {}
        node_name                                 = event["variables"]["node"]
        @event_data[view][node_name]            ||= {}
        @event_data[view][node_name]["events"]  ||= []
        @event_data[view][node_name]["url"]       = event["variables"]["node_url"]
        @event_data[view][node_name]["events"]   << build_event_hash(event)

        total += 1
        log "  Added event number #{total}" if total % 100 == 0

        last_processed_id = event["id"] if last_processed_id.nil? || event["id"] > last_processed_id
      end

      page += 1
    end

    @view_totals[view] = total
    log "  Total events for view #{view}: #{@view_totals[view]}"

    # Update the last processed ID
    @config["#{view.upcase.gsub(/\s/, "_")}_last_processed_id"] = last_processed_id

    log "-----------------------------------------------"
  end
end

def build_file_contents(events)
  file_contents = "File Path,Action,Username,Timestamp\n"
  events.each do |event|
    file_contents += "#{event["path"]},#{event["action"]},#{event["username"]},#{event["timestamp"]}\n"
  end
  file_contents
end

def check_for_existing_ticket(view, node)
  return nil if @event_actions.empty?
  matching_issue = nil

  # Build title
  log @event_actions
  title = @event_actions[view]["variables"]["title"].gsub(/{{\s*node\s*}}/, node).gsub(/{{ timestamp.*}}/, DateTime.now.strftime('%b %d, %Y'))

  log "  Checking for existing issue in JIRA with title \"#{title}\""

  endpoint  = "#{@config["JIRA_URL"]}/rest/api/2/search"
  body =  {
    "jql" => "summary~'\"#{title}\"' AND statusCategory != done",
    "startAt" => 0,
    "fields" => [
      "summary",
      "description",
      "labels",
      "project"
    ]
  }
  response = HTTParty.post(endpoint,
                            :headers    => { "Content-Type" => "application/json" },
                            :basic_auth => @jira_auth,
                            :body       => body.to_json,
                            :verify     => false)

  if response.nil? || response.code != 200
    raise "!!!!!! Call to JIRA instance failed with code #{response.code}"
  end

  if response['total'].to_i > 0
    response['issues'].each do |issue|
      if issue['fields']['project']['id'].to_i == @event_actions[view]["variables"]["project"].to_i && issue['fields']['summary'].to_s == title
        matching_issue = issue
        log "  Found ticket #{matching_issue["key"]} that the resulting issue will be combined with"
        break
      end
    end
  end

  log "  Found no matching issue" unless matching_issue
  matching_issue
end

def add_attachment(issue_key, file_contents)
  # Need to create the file to attach first
  file_path = "#{issue_key}_file_events_#{DateTime.now.strftime("%Y-%m-%d_%H-%M-%S")}.csv"
  endpoint  = "#{@config["JIRA_URL"]}/rest/api/2/issue/#{issue_key}/attachments"
  File.open(file_path, 'w') { |file| file.write(file_contents) }

  log "  Adding attachment..."

  resource = RestClient::Resource.new(endpoint, @config["JIRA_USERNAME"], @config["JIRA_PASSWORD"])
  response = resource.post({ file: File.new(file_path)}, { "X-Atlassian-Token" => "nocheck"} )

  if response.code != 200
    raise "    Attachment failed with code #{response.code}"
  end

  log "    Event detail attachment successfully uploaded to #{issue_key}"
end

def create_new_ticket(view, node, file_contents)
  # Try and get data from the action
  action        = @event_actions[view]
  project_id    = action["variables"]["project"]    ? action["variables"]["project"].to_i               : @config["JIRA_PROJECT_ID"].to_i
  issue_type_id = action["variables"]["issuetype"]  ? action["variables"]["issuetype"].to_i             : @config["JIRA_ISSUE_TYPE_ID"].to_i
  priority      = action["variables"]["priority"]   ? @priorities[action["variables"]["priority"].to_s] : @config["JIRA_PRIORITY"].to_s
  labels        = action["variables"]["label"]      ? [action["variables"]["label"]]                    : @config["JIRA_LABELS"]
  title         = action["variables"]["title"].gsub(/{{\s*node\s*}}/, node).gsub(/{{ timestamp.*}}/, DateTime.now.strftime('%b %d, %Y'))

  endpoint = "#{@config["JIRA_URL"]}/rest/api/2/issue"
  fields = {
    "project" => {
      "id" => project_id
    },
    "summary" => title,
    "description" => "Please refer to attachments for file event details",
    "issuetype" => {
      "id" => issue_type_id
    },
    "priority" => {
      "name" => priority
    },
    "labels" => labels
  }

  unless action["variables"]["body"].blank?
    body           = JSON.parse(action["variables"]["body"])
    body["fields"] = fields.merge(body["fields"])
  else
    body           = {}
    body["fields"] = fields
  end

  response  = HTTParty.post(endpoint,
                            :headers    => { "Content-Type" => "application/json" },
                            :basic_auth => @jira_auth,
                            :body       => body.to_json,
                            :verify     => false)


  unless response.code.to_i == 201
    raise "Failed to create JIRA ticket (code #{response.code}):\n#{response['errors']}"
  end

  log "  Created issue #{response["key"]} with title #{title}"

  # Now attach a file
  add_attachment(response["key"], file_contents)
end

def update_existing_ticket(node, file_contents, matching_issue)
  # Now attach a file
  add_attachment(matching_issue["key"], file_contents)
end

def check_for_existing_file(view, node)
  return nil if @event_actions.empty?
  matching_file = nil

  # Build title
  title = @event_actions[view]["variables"]["title"].gsub(/{{\s*node\s*}}/, node).gsub(/{{ timestamp.*}}/, DateTime.now.strftime('%b %d, %Y')).gsub(/\//, '-')

  log "  Checking for existing file with title \"#{title}\""

  filename = File.join(@to_directory, "#{title}.json")
  matching_file = filename if File.file?(filename)

  log "  Found no matching issue" unless matching_file
  matching_file
end

def create_new_file(view, node, file_contents)
  # Try and get data from the action
  action        = @event_actions[view]
  project_id    = action["variables"]["project"]    ? action["variables"]["project"].to_i               : @config["JIRA_PROJECT_ID"].to_i
  issue_type_id = action["variables"]["issuetype"]  ? action["variables"]["issuetype"].to_i             : @config["JIRA_ISSUE_TYPE_ID"].to_i
  priority      = action["variables"]["priority"]   ? @priorities[action["variables"]["priority"].to_s] : @config["JIRA_PRIORITY"].to_s
  labels        = action["variables"]["label"]      ? [action["variables"]["label"]]                    : @config["JIRA_LABELS"]
  title         = action["variables"]["title"].gsub(/{{\s*node\s*}}/, node).gsub(/{{ timestamp.*}}/, DateTime.now.strftime('%b %d, %Y')).gsub(/\//, '-')

  endpoint = "#{@config["JIRA_URL"]}/rest/api/2/issue"
  fields = {
    "project" => {
      "id" => project_id
    },
    "summary" => title,
    "description" => "Please refer to attachments for file event details",
    "issuetype" => {
      "id" => issue_type_id
    },
    "priority" => {
      "name" => priority
    },
    "labels" => labels
  }

  unless action["variables"]["body"].blank?
    body           = JSON.parse(action["variables"]["body"])
    body["fields"] = fields.merge(body["fields"])
  else
    body           = {}
    body["fields"] = fields
  end

  filename = File.join(@to_directory, "#{title}.json")
  log "  Creating file #{filename}"
  out_file = File.new(filename, "w")
  out_file.puts(body.to_json)
  out_file.close

  log "  Created file with title #{title}"

  # Add a line for the CSV
  update_existing_file(node, file_contents, filename)
end

def update_existing_file(node, file_contents, matching_file)
  # Write the number of lines in the CSV
  open(matching_file, 'a') { |f|
    f.puts "CSV attachment with #{file_contents.lines.count} lines"
  }
end

def process_events()
  @event_data.each_pair do |view, view_data|
    log "Processing events for view #{view}"

    view_data.each_pair do |node, data|
      log "  Processing events for node #{node}"

      # Build CSV file contents
      file_contents = build_file_contents(data["events"])
      log file_contents

      # Check if ticket exists already
      matching_issue = matching_file = nil
      matching_issue = check_for_existing_ticket(view, node) if @to_jira
      matching_file = check_for_existing_file(view, node) if @to_file

      if matching_issue
        log "    Adding to existing issue: #{matching_issue}"
        update_existing_ticket(node, file_contents, matching_issue)
      else
        if @to_jira
          log "    Creating a new issue"
          create_new_ticket(view, node, file_contents)
        end
      end

      if matching_file
        log "    Adding to existing file: #{matching_file}"
        update_existing_file(node, file_contents, matching_file)
      else
        if @to_file
          log "    Creating a new file"
          create_new_file(view, node, file_contents)
        end
      end

    end

  end

end

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
#
begin
  # Check to see if we just want to a field lookup pass to get ids for the events_config.yml file
  log "-----------------------------------------------"
  log "Getting field ids"
  log "NB: change @lookup_fields > true to log them"
  log "-----------------------------------------------"
  lookup_field_ids

  log "\n-----------------------------------------------"
  log "Event Action Gathering"
  log "-----------------------------------------------"
  gather_event_actions

  log "\n-----------------------------------------------"
  log "Event Gathering"
  log "-----------------------------------------------"
  gather_events

  if @event_data == {}
    log "\nNo new events to process"
  else
    log "\n-----------------------------------------------"
    log "Event Processing"
    log "-----------------------------------------------"
    process_events
  end

  # Write config back to file
  File.open("events_config.yml", 'w') { |file| file.write(@config.to_yaml) }
rescue Exception => e
  log "!!!!!!! ERROR !!!!!!!\n#{e.message}\n#{e.backtrace.join("\n")}"
end
