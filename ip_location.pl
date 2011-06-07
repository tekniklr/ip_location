#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Geo::IP;

# This script will:
#	1) Determine the external IP address of the current computer.
#	2) Do a GeoIP lookup on that IP to determine info about this 
#	   computer's current location.
#	3) Return this info.
# This can be used to, for instance, have a current and correct zip
# when retrieving online weather data or movie listings.  I wrote it
# specifically to interact with a weather plugin I use with conky.

#####################################################################
## Config
#####################################################################

# debug level- higher is more verbose; can also be changed at
# runtime with the --debug option
my $debug = 0;

# default IP to use in case of issues
my $default_zip = '14850';

# website to retrieve the IP from
my $ip_site = 'http://checkip.dyndns.org/';

# number of times to attempt to get the location data before failing
my $max_attempts = 10;

#####################################################################
## Stuff happens here
#####################################################################

my ($help, $data);

my %data_options = (
	'cc'=>'Country Code (2 letter)',
	'cc3'=>'Country Code (3 letter)',
	'cn'=>'Country Name',
	's'=>'State/Region Abbr.',
	'sn'=>'State/Region Name',
	'c'=>'City',
	'z'=>'Zip/Postal Code',
	'tz'=>'Time Zone',
	'lat'=>'Latitude',
	'long'=>'Longitude',
	'ac'=>'Area Code'
);

# parse arguments
my $options = GetOptions (
	"help|h|?" => \$help,
	"debug:1" => \$debug,
	"data|d=s" => \$data
);

# if debug is set in the config or on the command line, note this
$debug and warn "Debug level is $debug\n";
$debug ||= 0;

# print usage message and exit if requested
if ($help) {
	print "Usage: $0 [--help|-h|-?] [--debug[=<num>]] [--data|-d[=<cc|cc3|cn|s|sn|c|z|lat|long|tz|ac>]]\n";
	print "Where data defaults to z and is one of:\n";
	foreach (sort keys %data_options) {
		print "\t$_\t".$data_options{$_}."\n";
	}
	exit;
}

# ensure sanity of requested data
if (!$data || !exists $data_options{$data}) { 
	$data = 'z';
}
$debug and warn "Requested data: ".$data_options{$data}."\n";


# ensure we are connected to the Internet
my $testping = system("ping -c 1 cornell.edu 2>/dev/null | grep -q \"bytes from\"");
if ($testping != 0) {
	$debug and warn "No internet connectivity detected; returning default IP.\n";
	print $default_zip."\n";
	exit 1;
}

# get the external IP address
my $ip = `curl -s http://checkip.dyndns.org`;
$ip =~ s/.*?(\d+\.\d+\.\d+\.\d+).*/$1/s;
$debug and warn "Current IP: $ip\n";

# get geoip info for IP
my $attempts = 0;
FETCH:
my $gi = Geo::IP->open('/usr/share/GeoIP/GeoIPCity.dat', GEOIP_STANDARD);
my $gi_result = $gi->record_by_addr($ip);
if (!$gi_result && ($attempts < $max_attempts)) {
	$attempts++;
	goto FETCH;
}
if (!$gi_result) {
	die "Unable to fetch geoip data for IP ${ip}. Exiting.\n";
}

my ($country_code, $country_code_3, $country_name, $state, $state_name, $city, $zip, $lat, $long, $tz, $area_code);
$country_code = $gi_result->country_code;
$country_code_3 = $gi_result->country_code3;
$country_name = $gi_result->country_name;
$state = $gi_result->region;
$state_name = $gi_result->region_name;
$city = $gi_result->city;
$zip = $gi_result->postal_code;
$lat = $gi_result->latitude;
$long = $gi_result->longitude;
$tz = $gi_result->time_zone;
$area_code = $gi_result->area_code;
if ($debug > 0) {
	warn "GeoIP results for $ip:\n";
	warn "\tCountry Code:   \t$country_code\n";
	warn "\tCountry Code 3: \t$country_code_3\n";
	warn "\tCountry Name:   \t$country_name\n";
	warn "\tState:          \t$state\n";
	warn "\tState Name:     \t$state_name\n";
	warn "\tCity:           \t$city\n";
	warn "\tZip Code:       \t$zip\n";
	warn "\tLatitude:       \t$lat\n";
	warn "\tLongitude:      \t$long\n";
	warn "\tTime Zone:      \t$tz\n";
	warn "\tArea Code:      \t$area_code\n";
}

if ($data eq 'cc') { 
	print "$country_code";
}
elsif ($data eq 'cc3') {
	print "$country_code_3";
}
elsif ($data eq 'cn') {
	print "$country_name";
}
elsif ($data eq 's') {
	print "$state";
}
elsif ($data eq 'sn') {
	print "$state_name";
}
elsif ($data eq 'c') {
	print "$city";
}
elsif ($data eq 'z') {
	print "$zip";
}
elsif ($data eq 'tz') {
	print "$tz";
}
elsif ($data eq 'lat') {
	print "$lat";
}
elsif ($data eq 'long') {
	print "$long";
}
elsif ($data eq 'ac') {
	print "$area_code";
}
print "\n";
exit 0;
