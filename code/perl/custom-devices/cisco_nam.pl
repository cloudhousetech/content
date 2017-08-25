#!/usr/bin/perl
use strict;
use warnings;
use IPC::Run3;
use MIME::Base64;
use JSON;
use Data::Dumper;

use File::Basename;
use lib dirname (__FILE__);
use UpGuardCiscoParser;

my $debug = 0;
my $debug_dump_file = 1;

my $json = JSON->new->allow_nonref;


sub parse_management_port {
my $output = shift;

my $scan;
my $attrs;
my $ifname = undef;

$output =~ m/^\s*(\S+)\s*(.*)$/s;
$ifname = $1;
my $rest = $2;
foreach my $line (split (/\r*\n/, $rest)) {
$line =~ s/^\s*(.*?)\s*/$1/g;
if ($line =~ /(HWaddr) (\S+)/) {
$attrs->{$1} = $2;
} elsif ($line =~ /^inet /) {
my $inet;
while ($line =~ /(\S+):(\S+)/g) {
$inet->{$1} = $2;
}
$attrs->{"inet4"} = $inet;
} elsif ($line =~ /^inet6 addr:\s*(\S+)\/(\d+)\s*(.*)$/) {
my $addr = $1;
my $cidr = $2;
my $rest = $3;
my $inet;
$inet->{"addr"} = $addr;
$inet->{"cidr"} = $cidr;
while ($rest =~ /(\S+):(\S+)/g) {
$inet->{$1} = $2;
}
$attrs->{"inet6"} = $inet;
} else {
# add more here
}
}

if (defined($ifname)) {
$scan->{$ifname} = $attrs;
}
return $scan;
}

sub parse_web_users {
my $output = shift;

my $scan;
my $current_user;

foreach my $line (split (/\r*\n/, $output)) {
$line =~ s/^\s*(.*?)\s*/$1/g;
if ($line =~ m/^User\s*name\s*:\s*(.+?)$/) {
$current_user = $1;
$scan->{$current_user} = undef;
} elsif ($line =~ m/^(.+?)\s*?:\s*(.*?)$/) {
$scan->{$current_user}->{$1} = $2;
}
}

return $scan;
}


# use guardrail_agent helper to collect data
my $stdout;
my $stderr;
my @cmd = (
"guardrail_agent", "net_helper",
"--os", "script_path",
"--creds_in_stdin",
"--prep", "terminal length 0",
"--cmd", "show configuration",
"--cmd", "show interface management-port",
"--cmd", "show version",
"--cmd", "show web-users",
);
run3 \@cmd, undef, \$stdout, \$stderr or die "running guardrail helper failed: $!\n";
if ($? != 0) {
die "guardrail_agent returns stderr: $stderr\n";
}

# output is one base64 line per cmd
my @outputs;
foreach my $b64 (split(/\r*\n/, $stdout)) {
push @outputs, decode_base64($b64); 
}

warn "outputs: @outputs" if $debug > 3;

my $scan;

# "show configuration" is output 0.
# we're going to run this through the basic cisco parser
if (1) {
@cmd = (
"guardrail_agent", "scan_from_stdin",
"--os", "cios",
);
my $stdin = $outputs[0];
$stdout = undef;
$stderr = undef;
run3 \@cmd, \$stdin, \$stdout, \$stderr or die "running guardrail helper failed: $!\n";
if ($? != 0) {
die "guardrail_agent returns stderr: $stderr\n";
}

$scan = decode_json($stdout);
}

# "show interface management_port" is output 1.
$_ = parse_management_port($outputs[1]);
if (defined($_)) {
$scan->{"interface"} = undef;
$scan->{"interface"}->{"management_port"} = $_;
}

# "show version" is output 2.
$scan->{"inventory"} = undef;
$scan->{"inventory"}->{"facts"} = UpGuardCiscoParser::parse_output($outputs[2]);

# "show web-users" is output 3.
$_ = parse_web_users($outputs[3]);
if (defined($_)) {
$scan->{"web-users"} = undef;
$scan->{"web-users"}->{"web-users"} = $_;
}

print $json->pretty->encode($scan);

if ($debug_dump_file) {
my $fh;
open($fh, ">/tmp/ciscoNAM ") or die "could not open out: $!\n";
print $fh "stdout:"."\n";
print $fh $stdout;
print $fh "scan:"."\n";
print $fh Dumper($scan)."\n";
close $fh;
}