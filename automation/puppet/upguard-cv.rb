#############################################################################################################
#                                                                                                           #
# Author: UpGuard (support@upguard.com)                                                                     #
#                                                                                                           #
# Description: Synchronize UpGuard policy results with a corresponding JIRA ticket (continuous validation). #
# When an UpGuard policy fails, a failing ticket is create in JIRA if one does not already exist.           #
# If a ticket does exist, append a comment with the latest policy failure results and a link to the         #
# node scan. A passing UpGuard policy with a corresponding failing JIRA ticket will update the JIRA         #
# ticket status to "Passing" and append a comment with the passing UpGuard policy results.                  #
# Finally, a passing UpGuard policy with no corresponding JIRA ticket will not do anything.                 #
#                                                                                                           #
# Usage: This script is intended to be scheduled and run every minute using a tool such as crontab.         #
# UpGuard class variables will need to be set as per your UpGuard and JIRA instances.                       #
#                                                                                                           #
#############################################################################################################

require 'httparty'
require 'fileutils'

def main
  ug = UpGuard.new
  ug.create_lock
  state = ug.read_state
  events = ug.events_since_last_run(state)
  if events.count == 0
    ug.my_quit('no events to process, nothing to do, quitting')
  else
    ug.my_puts('INFO', "found #{events.count} node(s) to process")
    tickets = ug.get_failing_jira_tickets
    ug.my_puts('INFO', "found #{tickets['total']} tickets(s) to validate")
    ug.validate_jira_tickets(events, tickets)
    ug.my_quit('done')
  end
end

class UpGuard
  @version         = 'v0.0.1'
  @file_name       = File.basename(__FILE__)
  @file_name_state = "#{@file_name}.json"
  @file_name_lock  = "#{@file_name}.lock"

  @jira_hostname    = 'https://your.jira.instance'
  @jira_username    = 'username'
  @jira_password    = 'password'
  @jira_project_id  = 'project name'

  @hostname  = 'https://your.upguard.instance'
  api_key    = 'api key'
  secret_key = 'secret key'
  @auth      = "#{api_key}#{secret_key}"

  @events_index = "#{@hostname}/api/v2/events"

  class << self; attr_accessor :version, :file_name, :file_name_state, :file_name_lock,
                               :jira_hostname, :jira_username, :jira_password, :jira_project_id,
                               :hostname, :auth,
                               :events_index
  end

  def validate_jira_tickets(node_events, failing_tickets)
    if !node_events.is_a?(Array) || !failing_tickets.is_a?(Hash)
      my_quit('node events or tickets not supplied')
    end

    updated_count = 0
    created_count = 0

    node_events.each do |node|
      jira_ticket          = nil
      node_overall_failing = node[:overall_failing]

      # Go see if a JIRA ticket exists already for this node

      if failing_tickets['total'] > 0
        failing_tickets['issues'].each do |t|
          # Hacky. Node name needs to be the first label.
          next unless t['fields']['labels'][0] == node[:node_name]
          # Found our ticket.
          jira_ticket = t
        end
      end

      # The meat and potatoes of the integration.

      if !node_overall_failing
        if jira_ticket.nil?
          # Do nothing. UpGuard policy is passing. No JIRA ticket to update.
        else
          # We have a failing ticket to update. Transition the ticket to the "Passing" status
          transition_jira_ticket(jira_ticket, 'Passed')
          create_jira_comment(jira_ticket, node)
          updated_count += 1
        end
      else # UpGuard policy is failing.
        if jira_ticket.nil?
          # Create a ticket.
          create_jira_ticket(node)
          # Update our list of failing tickets.
          failing_tickets = get_failing_jira_tickets
          created_count += 1
        else
          # Found a ticket to update with a comment.
          create_jira_comment(jira_ticket, node)
          updated_count += 1
        end
      end
    end

    my_puts('INFO', "created #{created_count} ticket(s)")
    my_puts('INFO', "updated #{updated_count} ticket(s)")
  end

  def create_jira_comment(ticket, node)
    comment = {}
    comment[:body] = draw_policy_table(node)

    auth = { :username => "#{UpGuard.jira_username}", :password => "#{UpGuard.jira_password}" }
    comment_response = HTTParty.post("#{UpGuard.jira_hostname}/rest/api/2/issue/#{ticket['id']}/comment",
                                    :headers  => { 'Content-Type' => 'application/json',
                                                   'Accept' => 'application/json' },
                                    :body => comment.to_json,
                                    :basic_auth => auth
    ).to_hash

    my_puts('DEBUG', "comment response: #{comment_response}")

    if comment_response['id'].nil?
      my_quit('comment could not be created')
    end
  end

  def draw_policy_table(node)
    policy_table = "||Policy Name||Result||\n"
    node[:policies].each do |p|
      p['variables']['success'] ? policy_status = '{color:#14892c}PASS{color}' : policy_status = '{color:red}FAIL{color}'
      policy_table += "|#{p['variables']['policy']}|#{policy_status}|\n"
    end
    policy_table += "#{UpGuard.hostname}/node_groups#/nodes/#{node[:node_id]}?state=show&scan_id=#{node[:scan_id]}"
    policy_table
  end

  def transition_jira_ticket(ticket, status)
    # Ticket created. Lookup transitions available and move ticket to destination status.
    auth = { :username => "#{UpGuard.jira_username}", :password => "#{UpGuard.jira_password}" }
    transitions_response = HTTParty.get("#{UpGuard.jira_hostname}/rest/api/2/issue/#{ticket['id']}/transitions",
                                        :headers  => { 'Content-Type' => 'application/json',
                                                       'Accept' => 'application/json' },
                                        :basic_auth => auth
    ).to_hash

    my_puts('DEBUG', "transition response: #{transitions_response}")

    if transitions_response['transitions'].nil?
      my_quit('unable to get available ticket transitions')
    end

    failed_transition_id = -1
    transitions_response['transitions'].each do |transition|
      failed_transition_id = transition['id'] if transition['to']['name'] == status
    end

    my_puts('DEBUG',"failure_transition_id: #{failed_transition_id}")

    if failed_transition_id == -1
      my_quit('could not find the failure transition')
    end

    transition = {}
    transition['transition'] = {}
    transition['transition']['id'] = failed_transition_id

    # Time to move the ticket along to the desired status.
    move_response = HTTParty.post("#{UpGuard.jira_hostname}/rest/api/2/issue/#{ticket['id']}/transitions",
                                  :headers  => { 'Content-Type' => 'application/json',
                                                 'Accept' => 'application/json' },
                                  :body => transition.to_json,
                                  :basic_auth => auth
    )

    my_puts('DEBUG',"move response: #{move_response}")
  end

  def create_jira_ticket(node)
    ticket = {}
    ticket['fields'] = {}
    ticket['fields']['project'] = {}
    ticket['fields']['project']['key'] = 'COR'
    ticket['fields']['summary'] = "#{node[:node_name]} policies failing"
    ticket['fields']['description'] = draw_policy_table(node)
    ticket['fields']['issuetype'] = {}
    ticket['fields']['issuetype']['name'] = 'Server Scan'
    ticket['fields']['labels'] = [node[:node_name], 'upguard']

    auth = { :username => "#{UpGuard.jira_username}", :password => "#{UpGuard.jira_password}" }
    ticket_response = HTTParty.post("#{UpGuard.jira_hostname}/rest/api/2/issue/",
                                    :headers  => { 'Content-Type' => 'application/json',
                                                   'Accept' => 'application/json' },
                                    :body => ticket.to_json,
                                    :basic_auth => auth
    ).to_hash

    my_puts('DEBUG', "ticket_create_response: #{ticket_response}")

    if ticket_response['id'].nil?
      my_quit ('unable to create JIRA ticket')
    end

    transition_jira_ticket(ticket_response, 'Failed')
  end

  def events_since_last_run(state)
    begin
      unless state.is_a?(Hash)
        my_quit('failed to parse state file content: state is not a hash')
      end

      events = []
      node_events = []

      last_run = state['last_run']
      response = HTTParty.get("#{UpGuard.events_index}?view_name=Policy%20Ran&date_from=#{last_run}",
                              :headers  => { 'Content-Type' => 'application/json',
                                             'Accept' => 'application/json',
                                             'Authorization' => "Token token=\"#{UpGuard.auth}\"" }
      )
      events = JSON.parse(response.body)
      # Update the last_run variable if we got here.
      state['last_run'] = DateTime.now
      File.write(UpGuard.file_name_state, JSON.pretty_generate(state))

      if events.count == 0
        return events
      end

      # We have events of policy failures. Re-organise the array to group by nodes.
      grouped_events = events.group_by{|event| event['variables']['node']}
      my_puts('DEBUG', "grouped_events: #{grouped_events}")

      grouped_events.each do |event|
        node = {}
        node[:node_name] = event[0]
        # Sort events by created_at descending.
        time_desc_events = event[1].sort {|a,b| b['created_at'] <=> a['created_at']}
        my_puts('DEBUG', "time_desc_events: #{time_desc_events}")
        # Unique will consider "uniqueness" based on the first element it seems. Since elements are
        # sorted by time desc, this will be the "latest" policy failure ran event.
        unique_policies = time_desc_events.uniq {|a| a['variables']['policy_id']}
        my_puts('DEBUG', "unique_policies: #{unique_policies}")
        # Finally, sort the policies alphabetically.
        alphabetical_policies = unique_policies.sort {|a,b| a['variables']['policy'] <=> b['variables']['policy']}
        my_puts('DEBUG', "alphabetical_policies: #{alphabetical_policies}")
        node[:policies] = alphabetical_policies
        node[:node_id] = node[:policies][0]['variables']['node_id']
        node[:scan_id] = node[:policies][0]['variables']['scan_id']
        node[:overall_failing] = false
        node[:policies].each do |policy|
          unless policy['variables']['success']
            node[:overall_failing] = true
          end
        end
        node_events << node
      end

      my_puts('DEBUG', "node_events: #{node_events}")
      node_events
    rescue StandardError => e
      my_quit("retrieving UpGuard events: #{e}")
    end
  end

  def get_failing_jira_tickets
    begin
      jql = ERB::Util.url_encode("project = \"#{UpGuard.jira_project_id}\" AND type = \"Server Scan\" AND status = Failed order by created desc")
      auth = { :username => "#{UpGuard.jira_username}", :password => "#{UpGuard.jira_password}" }
      failing_tickets = HTTParty.get("#{UpGuard.jira_hostname}/rest/api/2/search?jql=#{jql}",
                                     :headers  => { 'Content-Type' => 'application/json',
                                                    'Accept' => 'application/json' },
                                     :basic_auth => auth
      ).to_hash
      my_puts('DEBUG', "failing_tickets: #{failing_tickets}")
      failing_tickets
    rescue StandardError => e
      my_quit("retrieving JIRA tickets: #{e}")
    end
  end

  def my_quit(message=nil)
    my_puts('FATAL', message) unless message.nil?
    delete_lock
    exit
  end

  def my_puts(log_level=nil, message=nil)
    if log_level.nil?
      log_level = 'LOG_LEVEL_EXCEPTION'
    end
    if message.nil?
      message = 'no message provided'
    end
    puts "#{UpGuard.file_name}: #{UpGuard.version}: #{log_level}: #{message}"
  end

  def create_lock
    my_puts('INFO', 'creating lock file')
    FileUtils.touch(UpGuard.file_name_lock) unless File.exist?(UpGuard.file_name_lock)
  end

  def delete_lock
    my_puts('INFO','deleting lock file')
    FileUtils.rm(UpGuard.file_name_lock) if File.exist?(UpGuard.file_name_lock)
  end

  def read_state
    if File.exist?(UpGuard.file_name_state)
      my_puts('INFO', 'reading state file')
      file_state = File.read(UpGuard.file_name_state)
      JSON.parse(file_state).to_hash
    else
      # Initialize the state file.
      my_puts('INFO','state file missing, creating')
      content = {}
      content['last_run'] = DateTime.now
      File.write(UpGuard.file_name_state, JSON.pretty_generate(content))
      content
    end
  end
end

main
