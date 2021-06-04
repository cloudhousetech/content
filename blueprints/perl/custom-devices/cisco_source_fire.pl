#!/usr/bin/env perl
use strict;
use warnings;
use IPC::Run3;
use MIME::Base64;
use JSON;
use Data::Dumper;

use File::Basename;
use lib dirname (__FILE__);

my $json = JSON->new->allow_nonref;
 
sub parse_output {
        my $lines = shift;
        my @lines = split(/\r*\n/, $lines);

        my $scan = {};

        foreach (@lines) {
                if (/^\s*Sourcefire\s*Linux\s*OS\s*([\w\d.]+)-(\S+)\s*$/) {
                        $scan->{"full_version"} = undef;
                        $scan->{"full_version"}->{"value"} = "$1-$2";
                        $scan->{"version"} = undef;
                        $scan->{"version"}->{"value"} = $1;
                        $scan->{"release"} = undef;
                        $scan->{"release"}->{"value"} = $2;
                }
        }

        #print Dumper($scan);

        my $ugscan;
        $ugscan->{"inventory"} = {};
        $ugscan->{"inventory"}->{"facts"} = $scan;

        return $ugscan;
}

sub collect_output {
        # use guardrail_agent helper to collect data
        my $stdout;
        my $stderr;
        my @cmd = ("guardrail_agent", "net_batch", "--os", "script_path", "--creds_in_stdin", "--cmd", "cat /etc/*release*");
        run3 \@cmd, undef, \$stdout, \$stderr or die "running guardrail helper failed: $!\n";
        if ($? != 0) {
                die "guardrail_agent returns stderr: $stderr\n";
        }

        # output is one base64 line per cmd
        my @outputs;
        foreach my $b64 (split(/\r*\n/, $stdout)) {
                push @outputs, decode_base64($b64);
        }

        return @outputs;
}

my @outputs = collect_output();
my $scan = parse_output($outputs[0]);
print $json->pretty->encode($scan);