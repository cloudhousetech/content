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
my @cmd = ("guardrail_agent", "net_batch", "--os", "script_path", "--creds_in_stdin", "--cmd", "cat /etc/version");
run3 \@cmd, undef, \$stdout, \$stderr or die "running guardrail helper failed: $!\n";
if($? !=0) {
        die "guardrail_agent returned non-zero\n";
}

# output is one base64 line per cmd
my @outputs;
foreach my $b64 (split(/\r*\n/, $stdout)) {
        push @outputs, decode_base64($b64);
}




# output is one line base64
my $scan;

# ugly scan assembling
$scan->{"version"} = undef;
$scan->{"version"}->{"version"} = undef;

# vmware -v is output 0.
if ( $outputs[0] =~ /^TrippLite\/B096\sVersion\s(.*)\s--/ ) {
        my $triplite;
        $triplite->{"version"} = $1;
        $scan->{"version"}->{"version"} = $triplite;
}
if(1){
        my $fh;
        open($fh, ">/tmp/tripliteDebug ") or die "could not open out: $!\n";
        print $fh "stdout $stdout\n";
        print $fh "stderr $stderr\n";
        print $fh "@outputs\n";
        print $fh "$scan\n";
        close $fh;
}
print $json->pretty->encode($scan);
