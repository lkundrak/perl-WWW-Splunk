use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
	module_name	=> 'Net::Splunk',
	license		=> 'perl',
	dist_author	=> 'Lubomir Rintel <lkundrak@v3.sk>',
	dist_version	=> '1.01',
	requires	=> {
		'Carp'		=> 0,
		'Getopt::Long'	=> 0,
		'HTTP::Request::Common' => 0,
		'LWP::UserAgent' => 0,
		'Pod::Usage'	=> 0,
		'Test::More'	=> 0,
		'Text::CSV'	=> 0,
		'XML::Feed'	=> 0,
		'XML::LibXML'	=> 0,
	},
	build_requires => {
		'Test::More'	=> 0,
		'XML::LibXML'	=> 0,
	}
);

$build->create_build_script;
