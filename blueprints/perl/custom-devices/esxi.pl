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
my @cmd = ("guardrail_agent", "net_batch", "--os", "script_path", "--creds_in_stdin", "--cmd", "vmware -v");
run3 \@cmd, undef, \$stdout, \$stderr or die "running guardrail helper failed: $!\n";
if($? !=0) {
        die "guardrail_agent returned non-zero\n";
}

# output is one base64 line per cmd
my @outputs;
foreach my $b64 (split(/\r*\n/, $stdout)) {
        push @outputs, decode_base64($b64);
}

if(1){ 
        my $fh;
        open($fh, ">/tmp/out2") or die "could not open out: $!\n";
        print $fh "stdout $stdout\n"; 
        print $fh "stderr $stderr\n";
        print $fh "@outputs\n"; 
        close $fh;
}


# output is one line base64
my $scan;

# ugly scan assembling
$scan->{"version"} = undef;
$scan->{"version"}->{"version"} = undef;
$scan->{"version"}->{"version"}->{"version"} = undef;

# vmware -v is output 0.
if ( $outputs[0] =~ /^\s*VMware\s+ESXi\s+(\S+)\s+build-(\S+)\s*$/ ) {
        my $vmwarev;
        $vmwarev->{"version"} = $1;
        $vmwarev->{"build"} = $2;
        $scan->{"version"}->{"version"}->{"version"} = $vmwarev;
}

print $json->pretty->encode($scan);
