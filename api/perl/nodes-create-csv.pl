#!/usr/bin/perl

use JSON::PP ("decode_json");
use HTTP::Request;
use LWP;
use URI::URL;

sub add_node {
    my (%args) = @_;

    my $body = new URI::URL;
    my %nodehash;
    foreach my $k (keys %args) {
    	$nodehash{"node[$k]"} = $args{$k};
    }

    $body->query_form(\%nodehash);
    my $body_content = $body->as_string;
    $body_content =~ s/^.//;

    # NB: Swap in your custom URL below if you have a dedicated instance
    my $url = new URI::URL "https://guardrail.scriptrock.com" . "/api/v1/nodes.json";
    my $request = HTTP::Request->new(POST => $url,
        HTTP::Headers->new("Authorization" => "Token token=\"ABCD123456EF7890GH\"",
        "Accept" => "application/json"));
    $request->content($body_content);
    my $browser = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });

    my $response = $browser->request($request);
    if ($response->is_success) {
        my $json = JSON::PP->new->decode($response->decoded_content);
        return $json;
    } else {
        print STDERR $response->status_line, "\n";
        return undef;
    }
}

my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
open(my $data, '<', $file) or die "Could not open '$file' $!\n";

while (my $line = <$data>) {
    chomp $line;
    my @fields = split "," , $line;
    if ($#fields == 5) {
    	add_node(
    	    name => $fields[0],
    	    node_type => $fields[1],
    	    medium_type => $fields[2],
    	    medium_password => $fields[3],
            medium_username => $fields[4],
            connection_manager_group_id => $fields[5]
    	);
    }
}
