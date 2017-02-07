#!/usr/bin/env ruby

require 'syslog'
require 'yaml'
require 'mail'
require 'eis/upguard'
require 'eis_remedyforce'

#
# Poll the UpGuard appliance for drift notifications and open RF incidents/send e-mail if found
#
# Looks for upguard_task_alerts.yml in /usr/local/etc for alerting information.
#

MAIL_FROM   = 'xxxxxxxxx@xxx.xxx'
CONFIG_FILE = '/usr/local/etc/upguard_task_alerts.yml'

def send_mail(subject, body, to)
  mail = Mail.new do
     to      to
     from    MAIL_FROM
     subject subject

     text_part do
       content_type 'text/plain; charset=us-ascii'
       body body
     end

   end

   mail.deliver
  
end

def log(msg)
  msg += ' (dryrun)' if @dryrun
  warn "#{Time.now.iso8601} #{msg}"
  @name ||= File::basename $0
  # syslog thinks % is a printf-style substitution, so they need to be escaped
  Syslog.open(@name, Syslog::LOG_PID | Syslog::LOG_CONS, Syslog::LOG_DAEMON) {|s| s.warning msg.to_s.gsub('%', '%%') }
end

# 2016-03-09 - TODO when the API gets fixed to return node info for node_offline, redo this section
def get_hostname(t)
  if t.node_offline?
    return t.description.match(/^(.*) is offline/)[1].downcase
  else
    return t.meta.node_name.downcase
  end
end

# create a table so we can look up by node name;  since order in the config file
# matters, if a node belongs to more than one group, only the first group (the highest priority)
# will be used
def create_lookup_table(alert_groups, upguard)
  lookup_table = {}
  alert_groups.keys.each do |group|
    upguard.node_group_lookup(group).members.map{|n| n.name.downcase }.each do |n|
      if !lookup_table.has_key?(n)
        lookup_table[n] = group
      end
    end
  end
  lookup_table
end

def main
  if !DATA.flock(File::LOCK_EX | File::LOCK_NB)
    log "ERROR: another instance is already running, quitting now";
    exit
  end
  
  @dryrun = ARGV.delete('-n') || ARGV.delete('-d')

  digest_emails = Hash.new{|h,k| h[k] = []}
  
  Mail.defaults do
    delivery_method :smtp, address: "xxxxxxxxx", port: 25
  end

  creds        = YAML.load_file(ENV['HOME'] + '/.sysadmin_config')['upguard']
  config       = YAML.load_file(CONFIG_FILE)
  alert_groups = config['alert_groups']

  rf      = EIS_Remedyforce.new
  upguard = EIS::Upguard.new(url: creds['url'], api_key: creds['api_key'], secret_key: creds['secret_key'], dryrun: @dryrun, debug: false)

  node_lookup_table = create_lookup_table(alert_groups, upguard)
  
  upguard.tasks.each do |t|

    # can't currently handle policy_failure or scan_failure - waiting for API update
    if t.policy_failure? || t.scan_failure?
      log "task #{t.id}: skipping, not enough information to handle #{t.source_type} tasks"
      next
    end
    
    hostname = get_hostname(t)
    
    unless node_lookup_table.has_key?(hostname)
      verb = 'skipping'
      if config['autoclose_other_tasks']
        verb = 'closing'
        t.close
      end
      log "task #{t.id}: #{verb}, #{hostname} not a member of any of the configured alerting groups"
      next
    end

    alert_config = alert_groups[node_lookup_table[hostname]]

    if t.drift_detected?
      begin
        url  = t.diff_url
      rescue StandardError => e
        log "task #{t.id}: error fetching diff for #{hostname}: #{e.message}, skipping"
        next
      end
      short_description = "UpGuard - #{hostname} drift task #{t.id}"
      description = "Task #{t.id}, #{t.created_at} - #{hostname}\n\n#{t.description}\n\ndiff: #{url}"
    elsif t.node_offline?
      short_description = "UpGuard - #{hostname} offline task #{t.id}"
      description = "Task #{t.id}, #{t.created_at} - #{t.description}"
    else
      log "task #{t.id}: skipping, I don't know how to handle tasks with source_type #{t.source_type}"
      next
    end

    case alert_config['method']
    when 'remedyforce'
      log "task #{t.id}: opening RemedyForce ticket for #{hostname} #{t.source_type} under #{alert_config['category']}"
      rf.create_incident(description, short_descr: short_description, category: alert_config['category'], check_existing: true) unless @dryrun
    when 'email'
      if alert_config['digest']
        log "task #{t.id}: adding #{hostname} #{t.source_type} to e-mail digest for #{alert_config['addresses']}"
        digest_emails[alert_config['addresses']] << description
      else
        log "task #{t.id}: sending e-mail for #{hostname} #{t.source_type} to #{alert_config['addresses']}"
        send_mail(short_description, description, alert_config['addresses']) unless @dryrun
      end
    else
      log "task #{t.id}: skipping, unknown alerting method #{alert_config['method']} for host #{hostname}'s group #{node_lookup_table[hostname]}"
      next
    end

    t.close

  end
  
  # send digest e-mails
  digest_emails.keys.each do |to|
    log "Sending e-mail digest to #{to}"
    send_mail("UpGuard alerts", digest_emails[to].join("\n\n---\n\n"), to) unless @dryrun
  end
    
  
end


main() if __FILE__ == $0


__END__
DO NOT REMOVE: required for the DATA flock call above
