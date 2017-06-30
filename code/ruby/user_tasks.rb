##################################################################
# Author: UpGuard                                                #
# Date: Jun 2017                                                 #
# Description: Creates a CSV list of open user tasks.            #
# Optionally allows the user to close tasks from CSV input.      #
##################################################################

require 'fileutils'
require 'csv'
require 'json'

$api_key           = "<< your_api_key >>"
$secret_key        = "<< your_secret_key >>"
$combined_key      = "#{$api_key}#{$secret_key}"
$upguard_instance  = "<< https://your.upguard.appliance >>"
$per_page          = 20
$page              = 1
$task_batch        = []
$filename          = "user-tasks.csv"
$filename_ready    = "user-tasks-ready-to-close.csv"
$close_tasks       = false

def get_tasks
  puts "  - Page #{$page}"
  response = `curl -X GET -s -k -H 'Authorization: Token token="#{$combined_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' '#{$upguard_instance}/api/v2/user_tasks?page=#{$page}&per_page=#{$per_page}'`
  if response.is_a?(String) && response.include?("id")
    new_tasks = JSON.load(response)
    $task_batch.push(new_tasks)
    return true
  else
    #puts "upguard: #{response}"
    return false
  end
end

def close_task(task_id)
  response = `curl -X POST -s -k -H 'Authorization: Token token="#{$combined_key}"' -H 'Accept: application/json' -H 'Content-Type: application/json' '#{$upguard_instance}/api/v2/user_tasks/#{task_id}/close'`
  if response == ""
    puts "task_id: #{task_id}: closed"
  else
    puts "task_id: #{task_id}: #{response}"
  end
end

if File.exist? $filename
  FileUtils.rm $filename
  File.open($filename, 'a') { |file| file.write("task_id, status, source_type, node_id, node_name, description, updated_at\n") }
end

puts "Loading user task pages..."
while get_tasks do
  $page = $page + 1;
end

$task_batch.each do |batch|
  batch.each do |task|

    node_id = 'Unavailable'
    node_name = 'Unavailable'

    if task['status'] == 1
      status = 'Unassigned'
    elsif task['status'] == 2
      status = 'Closed'
    else
      status = 'Assigned'
    end

    if task['source_type'] == 1
      source_type = 'Policy Failure'
    elsif task['source_type'] == 2
      source_type = 'Scan Failure'
    elsif task['source_type'] == 3
      source_type = 'Difference Detected'
    else
      source_type = 'Node Offline'
    end

    if task['meta'].is_a? Hash
      if !task['meta']['node_id'].nil?
        node_id = task['meta']['node_id']
      end

      if !task['meta']['node_name'].nil?
        node_name = task['meta']['node_name']
      end
    end

    line = "#{task['id']}, #{status}, #{source_type}, #{node_id}, #{node_name}, #{task['description']}, #{task['updated_at']}"
    File.open($filename, 'a') { |file| file.write("#{line}\n") }
  end
end

if $close_tasks
  puts "Closing user tasks..."
  csv = CSV.read($filename_ready, :headers=>true)
  if !csv['task_id'].nil?
    task_ids = csv['task_id']
    task_ids.each do |id|
      close_task(id)
    end
  else
    puts "CSV file is not formatted correctly."
  end
else
  puts "Set $close_tasks to true to close user tasks."
end