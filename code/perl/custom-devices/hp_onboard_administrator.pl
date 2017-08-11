#!/usr/bin/perl
use strict;
use warnings;
use IPC::Run3;
use MIME::Base64;
use JSON;
use Data::Dumper;

my $json = JSON->new->allow_nonref;


# use guardrail_agent helper to collect data
my $stdout;
my $stderr;
my @cmd = ("guardrail_agent", "net_helper", "--os", "script_path", "--creds_in_stdin", "--prep", "set script mode on", "--cmd", "show firmware summary", "--cmd", "show config");
run3 \@cmd, undef, \$stdout, \$stderr or die "running guardrail helper failed: $!\n";
if ($? != 0) {
        die "guardrail_agent returned non-zero\n";
}

# output is one base64 line per cmd
my @outputs;
foreach my $b64 (split(/\r*\n/, $stdout)) {
        push @outputs, decode_base64($b64);
}

if (1) {
        my $fh;
        open ($fh, ">/tmp/hp-onboard-administrator.log") or die "could not open out: $!\n";
        print $fh "stdout $stdout\n";
        print $fh "stderr $stderr\n";
        print $fh "@outputs\n";
        close $fh;
}

my $scan;

# ugly scan assembling

# "show firmware summary" is output 0.
my $last_was_blank = 0;
my $info_block = undef;
foreach (split(/\r*\n/, $outputs[0])) {
        my $this_is_blank = 0;
        if (/^\s*$/) {
                $this_is_blank = 1;
        }

        if ($last_was_blank && /^([\w\s]+?\s+Information)\s*$/) {
                $info_block = $1;
        }

        if (defined($info_block) && ($info_block eq "Onboard Administrator Firmware Information")) {
                if (/^(\d+)\s+(.*?)\s+([\d\w._-~]+)\s*$/) {
                        my $bay = $1;
                        my $model = $2;
                        my $firmware_version = $3;
                        my $attrs = {
                                "bay" => $bay,
                                "model" => $model,
                                "firmware version" => $firmware_version,
                        };
                        $scan->{"version"} ||= undef;
                        $scan->{"version"}->{"firmware"} ||= undef;
                        $scan->{"version"}->{"firmware"}->{"bay $bay"} = $attrs;
                }
        }

        $last_was_blank = $this_is_blank;
}

print $json->pretty->encode($scan);