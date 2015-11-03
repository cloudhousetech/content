

NEEDS TO BE CHANGED BEFORE ADDING TO DOCS SITE


use JSON::PP ("decode_json");
use HTTP::Request;
use LWP;
use URI::URL;

my $url = new URI::URL "http://localhost:3000" .
    "/api/v1/nodes/42/add_to_node_group.json?node_group_id=23"
my $request = HTTP::Request->new(GET => $url,
    HTTP::Headers->new("Authorization" => "Token token=\"AB123456CDEF7890GH\"",
    "Accept" => "application/json"));
my $browser = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });

my $response = $browser->request($request);
if ($response->is_success) {
    my $json = JSON::PP->new->decode($response->decoded_content);
    return $json;
} else {
    print STDERR $response->status_line, "\n";
    return undef;
}