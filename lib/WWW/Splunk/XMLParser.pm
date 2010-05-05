=head1 NAME

WWW::Splunk::XMLParser - Parse Splunk XML format

=head1 DESCRIPTION

This is an utility module to deal with XML format ocassionally returned
by Splunk and seemlingly undocumented.

Note that Splunk usually returns Atom XMLs, which have the same
content type. They can be distinguished by a DOCTYPE.

=cut

package WWW::Splunk::XMLParser;

use strict;
use warnings;

use XML::LibXML qw/:libxml/;
use Carp;

=head2 B<parse> (F<string>)

Return a perl structure from a XML string, if it's
parsable, otherwise return a raw XML::LibXML object

=cut
sub parse
{
	my $string = shift;

	my $xml = XML::LibXML->load_xml (string => $string);
	my @tree = eval { parsetree ($xml) };
	return @tree unless $@;
	undef $@;
	return $xml;
}

=head2 B<parsetree> (F<XML::LibXML::Node>)

Parse a XML node tree recursively.

=cut
sub parsetree
{
	my $xml = shift;
	my @retval;

	foreach my $node ($xml->childNodes ()) {

		# Not interested in anything but elements
		next unless $node->nodeType eq XML_ELEMENT_NODE;

		if ($node->nodeName () eq 'list') {
			push @retval, [ parsetree ($node) ];
		} elsif ($node->nodeName () eq 'dict') {
			push @retval, { parsetree ($node) };
		} elsif ($node->nodeName () eq 'key') {
			push @retval, $node->getAttribute ('name')
				=> $node->textContent;
		} elsif ($node->nodeName () eq 'response' or
			$node->nodeName () eq 'item') {
			# Basically just ignore these
			push @retval, parsetree ($node);
		} else {
			die "Unknown XML element: ".$node->nodeName
		}
	}

	return @retval;
}

=head1 SEE ALSO

L<WWW::Splunk>, L<WWW::Splunk::API>, L<XML::LibXML>

=head1 AUTHORS

Lubomir Rintel, L<< <lkundrak@v3.sk> >>

The code is hosted on GitHub L<http://github.com/lkundrak/perl-WWW-Splunk>.
Bug fixes and feature enhancements are always welcome.

=cut

1;
