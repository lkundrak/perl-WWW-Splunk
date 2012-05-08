=head1 NAME

WWW::Splunk - Client library for Splunk log search engine

=head1 SYNOPSIS

  use WWW::Splunk;

  my $splunk = new WWW::Splunk::API ({
          host    => $host,
          port    => $port,
          login   => $login,
          password => $password,
          unsafe_ssl => 1,
  });

  my $sid = $splunk->start_search ('selinux avc');
  $splunk->poll_search ($sid);
  until ($splunk->results_read ($sid)) {
    print scalar $splunk->search_results ($sid);
  }
  print " results found\n";

Please consider this an alpha quality code, whose API can change
at any time, until we reach version 2.0. There are known glitches
in the code quality now.
Remember the code is the best documentation for now.

=head1 DESCRIPTION

This module contains utility functions for Splunk 4.1
and 4.1.1 search API.

=cut

package WWW::Splunk;

use strict;
use warnings;

our $VERSION = '1.03';

use WWW::Splunk::API;
use Carp;
use Date::Manip;

use base qw/WWW::Splunk::API/;

=head2 B<start_search> (F<string>) [(F<since>)] [(F<until>]

Initiate a search, return a SID (Search ID) string.

=cut
sub start_search
{
	my $self = shift;
	my $string = shift;
	my $since = shift;
	my $until = shift;

	# Format dates
	($since, $until) = map { defined $_ ? scalar UnixDate (ParseDate ($_) || $_, '%O') || $_ : undef }
		($since, $until);

	$self->{results_consumed} = 0;
	my $response = $self->post ('/search/jobs', {
		search => "search $string",
		(defined $since ? (earliest_time => $since) : ()),
		(defined $until ? (latest_time => $until) : ()),
	});
	die 'Unexpected response format '
		unless $response and ref $response eq 'XML::LibXML::Document';
	my $sid = $response->findvalue ('/response/sid');
	croak "Bad response" unless defined $sid;
	return $sid;
}

=head2 B<search_done> (F<sid>)

Return true if the search is finished.

=cut
sub search_done
{
	my $self = shift;
	my $sid = shift;

	my $search = $self->get ('/search/jobs/'.$sid);
	return $search->{isDone};
}

=head2 B<poll_search> (F<sid>)

Wait for a search to finish.

=cut
sub poll_search
{
	my $self = shift;
	my $sid = shift;

	until ($self->search_done ($sid)) { sleep 1; }
}

=head2 B<search_results> (F<sid>)

Return an array of the matched events.
If called multiple times, it only returns events which
were added from the time of the last call.
Oh, and you can't run multiple search concurrently
with single L<WWW::Splunk> instance. Otherwise,
L<WWW::Splunk> is perfectly thread-safe.

=cut
sub search_results
{
	my $self = shift;
	my $sid = shift;

	my $done = $self->search_done ($sid);
	my @results = $self->get ('/search/jobs/'.$sid.'/results?count=1024&offset='.
		$self->{results_consumed});
	$self->{results_consumed} += scalar @results;
	$self->{last_read} = scalar @results if $done;

	return @results;
}

=head2 B<results_read> (F<sid>)

Return true if search is finished and all there are no
more results to read (everything was fetched with L<search_results>).

=cut
sub results_read
{
	my $self = shift;
	my $sid = shift;

	return undef if not defined $self->{last_read};
	return $self->{last_read} eq 0;
}

=head1 AUTHORS

Lubomir Rintel, L<< <lkundrak@v3.sk> >>

The code is hosted on GitHub L<http://github.com/lkundrak/perl-WWW-Splunk>.
Bug fixes and feature enhancements are always welcome.

=cut

1;
