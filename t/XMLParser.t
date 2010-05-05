use WWW::Splunk::XMLParser;
use Test::More tests => 5;

my $case1 = <<EOF;
<response>
	<dict>
		<key name="remoteSearch">search index=default readlevel=2 foo</key>
		<key name="remoteTimeOrdered">true</key>
	</dict>
	<list>
		<item>
			<dict>
				<key name="overridesTimeOrder">false</key>
				jjjjjjjjjjjjjjjjjjjj<key name="isStreamingOpRequired">false</key>

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
is_deeply ([ WWW::Splunk::XMLParser::parse ($case1) ], [
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

my $case2 = <<EOF;
<response>
		<woo>8086</woo>
	</hoo>
</response>
EOF
eval { WWW::Splunk::XMLParser::parse ($case2) };
like ($@, qr/parser error/, "Errored out on bad document");

my $case3 = <<EOF;
<?xml version=\'1.0\' encoding=\'UTF-8\'?>
<response><sid>666</sid></response>
EOF
my $result3 = WWW::Splunk::XMLParser::parse ($case3);
ok ($result3->isa ('XML::LibXML::Document'),
	"Raw document 1 not touched");
is ($result3->findvalue ('/response/sid'), 666,
	"LibXML deals with parsed document properly");

my $case4 = <<EOF;
<response>
	<messages>
		<msg type='FATAL'>Unknown sid.</msg>
	</messages>
</response>
EOF
ok (WWW::Splunk::XMLParser::parse ($case4)->isa ('XML::LibXML::Document'),
	"Raw document 2 not touched");
