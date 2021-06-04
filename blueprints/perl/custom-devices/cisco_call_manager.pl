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

my $json = JSON->new->allow_nonref;

# use guardrail_agent helper to collect data
my $stdout;
my $stderr;
my @cmd = ("guardrail_agent", "net_helper", "--os", "script_path", "--creds_in_stdin", "--cmd", "show version active");
run3 \@cmd, undef, \$stdout, \$stderr or die "running guardrail helper failed: $!\n";
if ($? != 0) {
        die "guardrail_agent returns stderr: $stderr\n";
}

# output is one base64 line per cmd
my @outputs;
foreach my $b64 (split(/\r*\n/, $stdout)) {
        push @outputs, decode_base64($b64);
}

my $scan;

# "show version active" is output 0.
$scan->{"inventory"} = undef;
$scan->{"inventory"}->{"facts"} = UpGuardCiscoParser::parse_output($outputs[0]);

print $json->pretty->encode($scan);