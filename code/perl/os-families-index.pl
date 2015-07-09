use JSON::PP ("decode_json");
use HTTP::Request;
use LWP;
use URI::URL;

my $url = new URI::URL "http://localhost:3000" .
    "/api/v1/operating_system_families.json";
my $request = HTTP::Request->new(GET => $url,
    HTTP::Headers->new("Authorization" => "Token token=\"AB123456CDEF7890GH\"",
    "Accept" => "application/json"));
my $browser = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });

my $response = $browser->request($request);
if ($response->is_success) {
    my $json = JSON::PP->new;
    $perl_scalar = $json->decode($response->decoded_content);
	    $pretty_printed = $json->pretty->encode($perl_scalar);
    print $pretty_printed;
} else {
    print STDERR $response->status_line, "\n";
    print undef;
}
