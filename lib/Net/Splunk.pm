=head1 NAME

Net::Splunk - Client library for Splunk log search engine

=head1 SYNOPSIS

  use Net::Splunk;

  my $splunk = new Net::Splunk::API ({
          host    => $host,
          port    => $port,
          login   => $login,
          password => $password,
          unsafe_ssl => 1,
  });

  my $sid = $splunk->start_search ('selinux avc');
  $splunk->poll_search ($sid);
  print scalar $splunk->search_results ($sid);
  print " results found\n";

Please consider this an alpha quality code, whose API can change
at any time, until we reach version 2.0. There are known glitches
in the code quality now.
Remember the code is the best documentation for now.

=head1 DESCRIPTION

This module contains utility functions for Splunk 4.1
and 4.1.1 search API.

=cut

package Net::Splunk;

use strict;
use warnings;

our $VERSION = '1.00';

use Net::Splunk::API;
use Carp;

use base qw/Net::Splunk::API/;

=head2 B<start_search> (F<string>)

Initiate a search, return a SID (Search ID) string.

=cut
sub start_search
{
	my $self = shift;
	my $string = shift;

	$self->{events_consumed} = 0;
	my @response = $self->post ('/search/jobs', {
		search => "search $string",
	});
	croak "Bad response" unless scalar @response == 2
		and $response[0] eq 'sid';
	my $sid = $response[1];
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
	return $search->{done};
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
with single L<Net::Splunk> instance. Otherwise,
L<Net::Splunk> is perfectly thread-safe.

=cut
sub search_results
{
	my $self = shift;
	my $sid = shift;

	my @events = $self->get ('/search/jobs/'.$sid.'/events?offset='.
		$self->{events_consumed});
	$self->{events_consumed} += scalar @events;

	return @events;
}

=head1 AUTHORS

Lubomir Rintel, L<< <lkundrak@v3.sk> >>

The code is hosted on GitHub L<http://github.com/lkundrak/perl-Net-Splunk>.
Bug fixes and feature enhancements are always welcome.

=cut

1;
