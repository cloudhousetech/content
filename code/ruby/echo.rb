# Contab usage: */1 * * * * /home/centos/.rvm/gems/ruby-2.4.1@lab/wrappers/ruby /scripts/echo.rb 'instance.upguard.org' 'login' '<!channel>: ' 2>&1 > /tmp/echo-instance.upguard.org.rb.log

require 'httparty'
require 'active_support/core_ext/numeric/time'

# Argument collecting
@hostname = ARGV[0]           # The instance you are wanting to check.
@expected_response = ARGV[1]  # The response you are expecting back from the above instance.
@message_mod = ARGV[2]        # Slack message alert level e.g.: <!channel>

puts "hostname: #{@hostname}"
puts "expected_response: #{@expected_response}"
puts "message_mod: #{@message_mod}"

def main
  # Raw curl here is preferred over using httparty so that the query can be easily copied into a terminal
  # for verification.
  response = `curl -v -k https://#{@hostname} 2>&1`
  violation_file = "/tmp/echo-#{@hostname}.offline.json"

  puts response

  if !response.include?(@expected_response)
    if File.exists? "#{violation_file}"
      content = {}
      violation_file_string = File.read(violation_file)
      violation_details = JSON.parse(violation_file_string)
      violation_instance = violation_details['violation_instance']
      violation_instance_next = violation_instance + 1
      violation_next_check_datetime = violation_details['next_check_datetime']
      violation_next_check_counter = violation_details['violation_next_check_counter']

      # Update the violation instance count
      content[:violation_instance] = violation_instance_next

      # Don't alert on the first instance.
      puts "Time.now: #{DateTime.now}"
      puts "Next check: #{DateTime.parse(violation_next_check_datetime)}"

      if (violation_instance.present? && violation_instance > 2) && (violation_next_check_datetime.present? && (DateTime.now >= DateTime.parse(violation_next_check_datetime)))
        violation_next_check_counter = violation_next_check_counter + 1
        send_chat("#{@message_mod}#{@hostname} has no login page. Violation instance #{violation_instance}. Checking again in #{fibonacci(violation_next_check_counter)} minute(s).", "#{response}")
        content[:violation_next_check_counter] = violation_next_check_counter
        content[:next_check_datetime] = fibonacci(violation_next_check_counter).minutes.from_now
      else
        # Don't increment the next check time.
        content[:violation_next_check_counter] = violation_next_check_counter
        content[:next_check_datetime] = violation_next_check_datetime
      end
      File.write(violation_file, content.to_json)
    else
      # Init
      content = {}
      content[:violation_instance] = 1
      content[:violation_next_check_counter] = 1
      content[:next_check_datetime] = fibonacci(content[:violation_instance]).minutes.from_now
      File.write(violation_file, content.to_json)
    end
  else
    if File.exists? "#{violation_file}"
      send_chat("#{@message_mod}#{@hostname} available again.", "")
      `rm #{violation_file}`
    end
  end
end

def send_chat(heading, text)
  slack_hook = "T034S9ZQJ/B034R6VAM/cf4J6habpjbhPeNORgGcOpLm"
  test_mode = false

  if !test_mode
    url = "https://hooks.slack.com/services/#{slack_hook}"
    attachments = []
    attachments_body = {}
    attachments_body[:color] = "danger"
    attachments_body[:pretext] = "#{heading}"
    attachments_body[:text] = "#{text}"
    attachments.push(attachments_body)
    HTTParty.post(url,:headers  => { 'Content-Type' => 'application/json' },
                  :body     => {
                      :channel     => "#testnotify",
                      :username    => "Online Check",
                      :attachments => attachments,
                      :icon_emoji  => "ghost",
                      :link_names  => 1
                  }.to_json)
  else
    puts text
  end
end

def fibonacci(n)
  n <= 1 ? n :  fibonacci( n - 1 ) + fibonacci( n - 2 )
end

main