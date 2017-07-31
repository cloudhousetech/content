#!/usr/bin/env perl
package UpGuardCiscoParser;

use strict;
use warnings;

use JSON;
use Data::Dumper;

my $json = JSON->new->allow_nonref;
 
sub parse_output {
	my $lines = shift;
	my @lines = split(/\r*\n/, $lines);

	my $scan = {};

	my $list_key = undef;
	my @list_values = ();

	# this forces one last trip through the state machine below to collect lists
	push @lines, "";

	foreach (@lines) {
		my $next_in_list = 0;
		my $next_list_key = undef;
		if (/^\s*[#!]/) {
			# ignore
		} elsif (/^\s*([^:]+)\s*:\s*$/) {
			# start of a list (colon suffix)
			$next_list_key = $1;
		} elsif (defined($list_key) && /^\s*([^:]+)\s*$/) {
			# list item (no colon)
			$next_list_key = $list_key;
			push @list_values, $1;
		} elsif (/^\s*([^:]+)\s*:\s*(.+?)\s*$/) {
			# single line key value
			my $attrs;
			$attrs->{"value"} = $2;
			$scan->{$1} = $attrs;
		} else {
		}

		if (defined($list_key) && (!defined($next_list_key) || ($list_key ne $next_list_key))) {
			my $attrs;
			my @store_list_values = @list_values;
			$attrs->{"value"} = \@store_list_values;
			$scan->{$list_key} = $attrs;
			@list_values = ();
		}

		$list_key = $next_list_key;
	}

	return $scan;
}

1;

