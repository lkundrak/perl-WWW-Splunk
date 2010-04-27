=head1 NAME

Net::Splunk::API - Splunk REST client

=head1 DESCRIPTION

L<Net::Splunk::API> is a low-level interface to Splunk
log search engine. It deals with HTTP communication as well as
working around certain interface glitches.

See L<http://www.splunk.com/base/Documentation/latest/Developer/RESTSearch>
for API definition.

This module is designed to be Splunk API version agnostic.

Please consider this an alpha quality code, whose API can change
at any time, until we reach version 2.0. There are known glitches
in the code quality now.
Remember the code is the best documentation for now.

=cut

package Net::Splunk::API;

use LWP::UserAgent;
use HTTP::Request::Common;
use XML::Feed;
use Text::CSV;
use Net::Splunk::XMLParser;
use Carp;

use strict;
use warnings;

our $VERSION = '1.00';
our $prefix = '/services';

=head2 B<new> (F<params>)

A constructor.

  my $splunk = new Net::Splunk::API ({
          host    => $host,
          port    => $port,
          login   => $login,
          password => $password,
          unsafe_ssl => 0,
  });

=cut
sub new
{
	my $class = shift;
	my $self = shift;

	$self->{url} ||= 'https://'.$self->{host}.':'.$self->{port};

	# Set up user agent unless an existing one was passed
	unless ($self->{agent}) {
		$self->{agent} = new LWP::UserAgent;
		$self->{agent}->cookie_jar ({});
		$self->{agent}->credentials (
			delete ($self->{host}).':'.(delete $self->{port}),
			'/splunk', delete $self->{login},
			delete $self->{password});
		$self->{agent}->agent ("$class/$VERSION ");
	}

	bless $self, $class;
}

=head2 B<parse_csv> (F<string>)

Make the splunk-produced CSV into a hash or
an array of hashes.

=cut
sub parse_csv
{
	my $content = shift;

	my @retval;
	my @header;
	my $line = 0;
	my $eiq;
	my $csv = new Text::CSV ({ binary => 1 });

	foreach (split /\n/, $content) {
		$line++;

		# Parse line. Continue previous one if
		# we encountered an EIQ error
		$_ = "$eiq\n$_" if $eiq;
		unless ($csv->parse ($_)) {
			my ($code, $msg, $col) = $csv->error_diag ();
			if ($code == 2027) {
				# "Quoted field not terminated"
				# Continue on the next line
				$eiq = $_;
				next;
			} else {
				croak "CSV Error: $msg ($line:$col)";
			}
		}
		undef $eiq;
		my @fields = $csv->fields ();

		# First line?
		unless (@header) {
			@header = @fields;
			next;
		}

		# Lines into hashes
		push @retval, { map {
			$_ =~ /^__/ ? () : ($_ => shift @fields)
		} @header };
	}

	return $#retval ? @retval : $retval[0];
}

=head2 B<delete> (F<parameters>)

Wrapper around HTTP::Request::Common::DELETE ().

=cut
sub delete
{
	my $self = shift;
	$self->request (\&DELETE, @_);
}

=head2 B<post> (F<parameters>)

Wrapper around HTTP::Request::Common::POST ().

=cut
sub post
{
	my $self = shift;
	$self->request (\&POST, @_);
}

=head2 B<get> (F<parameters>)

Wrapper around HTTP::Request::Common::GET ().

=cut
sub get
{
	my $self = shift;
	$self->request (\&GET, @_);
}

=head2 B<head> (F<parameters>)

Wrapper around HTTP::Request::Common::HEAD ().
Not used anywhere in splunk API

=cut
sub head
{
	my $self = shift;
	$self->request (\&HEAD, @_);
}

=head2 B<put> (F<parameters>)

Wrapper around HTTP::Request::Common::PUT ().
Not used anywhere in splunk API

=cut
sub put
{
	my $self = shift;
	$self->request (\&PUT, @_);
}

=head2 B<request> (F<method>, F<location>)

Request a Splunk api and deal with the results.

=cut
sub request {
	my $self = shift;
	my $method = shift;
	my $location = shift;

	my $url = $self->{url}.$prefix.$location;

	# Construct the request
	my $request;
	if (ref $method and ref $method eq 'CODE') {
		# Most likely a HTTP::Request::Common
		$request = $method->($url, @_);
	} else {
		# Most likely a HTTP::Request::Common
		$request = new HTTP::Request ($method, $url);
	}

	# TODO: We should inject parameters more elegantly
	my $output_mode = 'csv';
	if ($request->method eq 'POST') {
		$request->content (($request->content ? $request->content.'&' : '').
			'output_mode='.$output_mode);
		$request->header ('Content-Length' => length ($request->content));
	} else {
		$request->uri ($request->uri.($request->uri =~ /\?/ ? '&' : '?').
			'output_mode='.$output_mode);
	};

	# Run it
	my $response = $self->{agent}->request ($request);

	# Deal with HTTPS errors
	if ($_ = $response->header ('Client-SSL-Warning')) {
		# Why does LWP tolerate these by default?
		croak "SSL Error: $_" unless $self->{unsafe_ssl};
	}

	# Deal with HTTP errors
	unless ($response->is_success) {
		croak "HTTP Error: ".$response->status_line."\n".$response->content;
	}

	# Parse content
	unless (($_ = $response->header ('Content-Type')) =~ /^([^\s;]+)/) {
		croak "Missing or invalid Content-Type: $_";
	}
	if ($1 eq 'text/xml') {

		# Attempt to parse Atom XML
		my $xml = XML::Feed->parse (\$response->content);
		return $xml if $xml;

		# Not an atom, well maybe it's Splunk response format
		return Net::Splunk::XMLParser::parse ($response->content);
	} elsif ($1 eq 'text/csv') {
		# Make the lines into dictionaries
		return parse_csv ($response->content);
	} elsif ($response->code eq 204) {
		# "No content"
		# Happens when events are requested immediately
		# after the job is enqueued. With a text/plain content type
		# Empty array is the least disturbing thing to return here
		return ();
	} elsif ($1 eq 'text/plain') {
		# Sometimes an empty text/plain body is sent
		# even without 204 return code.
		return ();
	} else {
		# TODO: We probably can't do much about RAW
		# format, yet we could parse at least JSON
		use Data::Dumper;
		die Dumper $response;
		croak "Unknown content type: $1";
	}
}

=head1 SEE ALSO

L<Net::Splunk>, L<sc>

=head1 AUTHORS

Lubomir Rintel, L<< <lkundrak@v3.sk> >>

The code is hosted on GitHub L<http://github.com/lkundrak/perl-Net-Splunk>.
Bug fixes and feature enhancements are always welcome.

=cut
