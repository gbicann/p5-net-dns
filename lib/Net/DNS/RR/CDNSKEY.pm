package Net::DNS::RR::CDNSKEY;

#
# $Id$
#
our $VERSION = (qw$LastChangedRevision$)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR::DNSKEY);

=head1 NAME

Net::DNS::RR::CDNSKEY - DNS CDNSKEY resource record

=cut


use integer;


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return $self->SUPER::_format_rdata()
			if scalar grep $_, @{$self}{qw(flags algorithm)};
	return defined $self->{algorithm} ? '0 3 0 0' : '';	# RFC8078 mandated notation
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	return $self->SUPER::_parse_rdata(@_) if $_[2];
	die 'invalid RDATA (DNSKEY delete)'   if "@_" !~ m/^0 3 0/;    # ignore key
	$self->algorithm(0);
}


sub algorithm {
	my ( $self, $arg ) = @_;

	return $self->SUPER::algorithm($arg) if $arg;
	return $self->SUPER::algorithm() unless defined $arg;
	@{$self}{qw(flags protocol algorithm keybin)} = ( 0, 3, 0, '' );
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name CDNSKEY flags protocol algorithm publickey');

=head1 DESCRIPTION

DNS Child DNSKEY resource record

This is a clone of the DNSKEY record and inherits all properties of
the Net::DNS::RR::DNSKEY class.

Please see the L<Net::DNS::RR::DNSKEY> perl documentation for details.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.



=head1 COPYRIGHT

Copyright (c)2014,2017 Dick Franks

All rights reserved.

Package template (c)2009,2012 O.M.Kolkman and R.W.Franks.


=head1 LICENSE

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted, provided
that the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation, and that the name of the author not be used in advertising
or publicity pertaining to distribution of the software without specific
prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.


=head1 SEE ALSO

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, L<Net::DNS::RR::DNSKEY>, RFC7344, RFC8078

=cut
