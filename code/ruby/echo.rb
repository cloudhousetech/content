require 'httparty'

$hostname = "dogfood.upguard.org"

# Raw curl here is preferred over using httparty so that the query can be easily copied into a terminal
# for verification.
response = `curl -v -k -X GET https://#{$hostname} 2>&1`

puts response

tmp_file = "/tmp/#{$hostname}_offline"
$test_mode = false

def send_chat(heading, text)
  if !$test_mode
    url       = 'https://hooks.slack.com/services/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'
    attachments = []
    attachments_body = {}
    attachments_body[:color] = "danger"
    attachments_body[:pretext] = "#{heading}"
    attachments_body[:text] = "#{text}"
    attachments.push(attachments_body)
    slack_response  = HTTParty.post(url,  :headers  => { 'Content-Type' => 'application/json' },
                                    :body     => {
                                        :channel     => "#testnotify",
                                        :username    => "#{$hostname} Server Check",
                                        :attachments => attachments,
                                        :icon_emoji  => "ghost",
                                        :link_names  => 1
                                    }.to_json)
  else
    puts text
  end
end

if !response.include?('login')
  send_chat("<!channel>: #{$hostname} has no login page.", "#{response}")
  `touch #{tmp_file}` unless File.exists? "#{tmp_file}"
else
  send_chat("<!channel>: #{$hostname} available again.", "") if File.exists? "#{tmp_file}"
  `rm #{tmp_file}` if File.exists? "#{tmp_file}"
end
