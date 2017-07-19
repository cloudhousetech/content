require 'httparty' # Slack integration.

# Argument collecting
@hostname = ARGV[0]           # The instance you are wanting to check.
@expected_response = ARGV[1]  # The response you are expecting back from the above instance.
@message_mod = ARGV[2]        # Slack message alert level e.g.: <!channel>

def main
  # Raw curl here is preferred over using httparty so that the query can be easily copied into a terminal
  # for verification.
  response = `curl -v -k https://#{@hostname} 2>&1`
  tmp_file = "/tmp/#{$hostname}_offline"

  puts response

  if !response.include?(@expected_response)
    send_chat("#{@message_mod}: #{@hostname} has no login page.", "#{response}")
    `touch #{tmp_file}` unless File.exists? "#{tmp_file}"
  else
    send_chat("#{@message_mod}: #{@hostname} available again.", "") if File.exists? "#{tmp_file}"
    `rm #{tmp_file}` if File.exists? "#{tmp_file}"
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
                      :username    => "#{@hostname} Server Check",
                      :attachments => attachments,
                      :icon_emoji  => "ghost",
                      :link_names  => 1
                  }.to_json)
  else
    puts text
  end
end

main
