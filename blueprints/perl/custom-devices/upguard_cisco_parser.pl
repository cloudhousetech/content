#!/usr/bin/env perl
package UpGuardCiscoParser;

use strict;
use warnings;

use JSON;
use Data::Dumper;

my $json = JSON->new->allow_nonref;
my $debug = 0;
 
sub parse_output {
        my $lines = shift;
        my @lines = split(/\r*\n/, $lines);

        my $scan = {};

        my $list_key = undef;
        my @list_values = ();
        my $map_values = undef;

        # this forces one last trip through the state machine below to collect lists
        push @lines, "!";

        foreach (@lines) {
                my $next_in_list = 0;
                my $next_list_key = undef;
                if (/^\s*[#!]/) {
                        warn "$_" if $debug > 5;
                        # ignore
                } elsif (/^\s*$/) {
                        warn "$_" if $debug > 5;
                        # blank line, maintain list state
                        $next_list_key = $list_key;
                } elsif (/^\s*([^:]+)\s*:\s*$/) {
                        warn "$_" if $debug > 5;
                        # start of a list (colon suffix)
                        $next_list_key = $1;
                } elsif (defined($list_key) && /^\s*(.*?\d+)\s+Patch:\s*(.*?)\s*Description:\s*(.*?)\s*$/) {
                        warn "$_" if $debug > 5;
                        $next_list_key = $list_key;
                        my $patch;
                        $patch->{"date"} = $1;
                        $patch->{"name"} = $2;
                        $patch->{"description"} = $3;
                        $map_values->{$2} = $patch;
                } elsif (defined($list_key) && /^\s*([^:]+)\s*$/) {
                        warn "$_" if $debug > 5;
                        # list item (no colon)
                        $next_list_key = $list_key;
                        push @list_values, $1;
                } elsif (/^\s*([^:]+)\s*:\s*(.+?)\s*$/) {
                        warn "$_" if $debug > 5;
                        # single line key value
                        my $attrs;
                        $attrs->{"value"} = $2;
                        $scan->{$1} = $attrs;
                } else {
                        warn "$_" if $debug > 5;
                }

                if (defined($list_key) && (!defined($next_list_key) || ($list_key ne $next_list_key))) {
                        warn "LIST $#list_values MAP $map_values" if $debug > 4;
                        if ($#list_values >= 0) {
                                my $attrs;
                                my @store_list_values = @list_values;
                                $attrs->{"value"} = \@store_list_values;
                                $scan->{$list_key} = $attrs;
                        } elsif (defined($map_values)) {
                                $scan->{$list_key} = $map_values;
                        }
                        @list_values = ();
                        $map_values = undef;
                }

                $list_key = $next_list_key;
        }

        return $scan;
}

1;