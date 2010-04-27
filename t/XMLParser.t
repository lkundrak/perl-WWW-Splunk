use Net::Splunk::XMLParser;
use Test::More tests => 3;

my $case1 = <<EOF;
<?xml version=\'1.0\' encoding=\'UTF-8\'?>
<response><sid>666</sid></response>
EOF
is_deeply ([ Net::Splunk::XMLParser::parse ($case1) ],
	[ sid => 666 ], "Simple document parsed correctly");

my $case2 = <<EOF;
<response>
	<dict>
		<key name="remoteSearch">search index=default readlevel=2 foo</key>
		<key name="remoteTimeOrdered">true</key>
	</dict>
	<list>
		<item>
			<dict>
				<key name="overridesTimeOrder">false</key>
				<key name="isStreamingOpRequired">false</key>

			</dict>
		</item>
		<item>
			<dict>
			</dict>
			<dict>
			</dict>
		</item>
	</list>
</response>
EOF
is_deeply ([ Net::Splunk::XMLParser::parse ($case2) ], [
	{
		'remoteSearch' => 'search index=default readlevel=2 foo',
		'remoteTimeOrdered' => 'true'
	},
	[
		{
		'isStreamingOpRequired' => 'false',
		'overridesTimeOrder' => 'false'
		},
		{},
		{}
	],
	], "Structured document parsed correctly");

my $case3 = <<EOF;
<response>
	<hoo>
		<woo>8086</woo>
	</hoo>
</response>
EOF
eval { Net::Splunk::XMLParser::parse ($case3) };
like ($@, qr/^Unknown XML element: hoo/, "Errored out on bad document");
