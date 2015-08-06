#!/usr/bin/perl

use JSON::PP ("decode_json");
use HTTP::Request;
use LWP;
use URI::URL;

my $node = {
    name => "host.com",
    node_type => "SV",
    medium_type => 3,
    medium_username => "username",
    medium_hostname => "hostname",
    connection_manager_group_id => 1
}

my $body = new URI::URL;
$body->query_form(%node);
my $body_content = $body->as_string;
$body_content =~ s/^.//;

# NB: Swap in your custom URL below if you have a dedicated instance
my $url = new URI::URL "https://guardrail.scriptrock.com" .
    "/api/v1/nodes.json"
my $request = HTTP::Request->new(GET => $url,
HTTP::Headers->new("Authorization" => "Token token=\"AB123456CDEF7890GH\"",
    "Accept" => "application/json",
    "Content-Type" => "application/json"));
$request->content($body_content);
my $browser = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });

my $response = $browser->request($request);
if ($response->is_success) {
    my $json = JSON::PP->new;
    $perl_scalar = $json->decode($response->decoded_content);
    $pretty_printed = $json->pretty->encode( $perl_scalar ); # pretty-printing
    print $pretty_printed;
} else {
    print STDERR $response->status_line, "\n";
    print undef;
}
