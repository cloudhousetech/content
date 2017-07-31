#!/usr/bin/env perl
use strict;
use warnings;

use Expect;
use JSON;
use Data::Dumper;

my $json = JSON->new->allow_nonref;

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
	$ugscan->{"facts"} = {};
	$ugscan->{"facts"}->{"version"} = $scan;

	return $json->pretty->encode($ugscan);
}

sub collect_output {
	my $output = "";

	my @args = ($ARGV[0], $ARGV[1]);
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

$output->collect_output("ipaddress", "9999");
$pretty_output->parse_output($output);

if (1) {
    my $fh;
    open ($fh, ">/tmp/lantonix.log") or die "could not open out: $!\n";
    print $fh "output $output\n";
    print $fh "pretty_output $pretty_output\n";
    close $fh;
}

print $pretty_output;

#for (my $i = 0; $i <= $#ARGV; $i++) {
#	my $data = `cat "$ARGV[$i]"`;
#	print parse_output($data);
#}


