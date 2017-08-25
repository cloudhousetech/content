#!/usr/bin/env perl
use strict;
use warnings;

use Expect;
use JSON;
use Data::Dumper;

my $json = JSON->new->allow_nonref;

sub parse_creds {
        my $in = shift;
        my $creds = decode_json($in);
        $creds->{"port"} ||= 23;
        #print Dumper($creds);
        return $creds;
}

sub parse_output {
        my $lines = shift;
        my @lines = split(/\r*\n/, $lines);

        my $scan = {};

        foreach (@lines) {
                if (/^\s*\**\s+Lantronix\s+(\S+)\s+Device\s+Server\s+\**\s*$/) {
                        $scan->{"model"} = undef;
                        $scan->{"model"}->{"value"} = $1;
                } elsif (/^\s*MAC\s+address\s+(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)\s*$/) {
                        $scan->{"MAC address"} = undef;
                        $scan->{"MAC address"}->{"value"} = "$1:$2:$3:$4:$5:$6";
                } elsif (/^\s*Software\s+version\s+(\S+)\s+\((\S+)\)\s*$/) {
                        $scan->{"software version"} = undef;
                        $scan->{"software version"}->{"value"} = $1;
                        $scan->{"software release"} = undef;
                        $scan->{"software release"}->{"value"} = $2;
                }
        }

        #print Dumper($scan);

        my $ugscan;
        $ugscan->{"inventory"} = {};
        $ugscan->{"inventory"}->{"facts"} = $scan;
        return $ugscan;
}

sub collect_output {
        my $output = "";
        my $creds = shift;

        my @args = ($creds->{"hostname"}, $creds->{"port"});
        #warn "args: @args\n";
        my $exp = Expect->spawn("telnet", @args) or die "Cannot spawn telnet: $!\n";;
        $exp->log_stdout(0);

        my $done = 0;
        while (!$done) {
                $exp->expect(10,
                        [
                                qr/[Pp]assword:/ =>
                                sub {
                                        my $exp = shift;
                                        $output .= $exp->before();
                                        $exp->send("\r");
                                        exp_continue;
                                } ],
                        [
                                qr/[Lo]gin:/ => 
                                sub {
                                        my $exp = shift;
                                        $output .= $exp->before();
                                        $exp->send("\r");
                                        exp_continue;
                                } ],
                        [
                                eof =>
                                sub {
                                        $output .= $exp->before();
                                        $done = 1;
                                }
                        ],
                        [
                                timeout =>
                                sub {
                                        $output .= $exp->before();
                                        $done = 1;
                                }
                        ],
                );
        }
        $exp->soft_close();
        return $output;
}

my $stdin = "";
while (<STDIN>) { $stdin .= $_; }
my $creds = parse_creds($stdin);
my $output = collect_output($creds);
my $scan = parse_output($output);

if (1) {
        my $fh;
        open($fh, ">/tmp/lantronixDebug ") or die "could not open out: $!\n";
        print $fh "output $output\n";
        print $fh Dumper($scan)."\n";
        close $fh;
}

print $json->pretty->encode($scan);