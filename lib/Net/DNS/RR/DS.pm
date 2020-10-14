package Net::DNS::RR::DS;

use strict;
use warnings;
our $VERSION = (qw$Id$)[2];

use base qw(Net::DNS::RR);


=head1 NAME

Net::DNS::RR::DS - DNS DS resource record

=cut

use integer;

use Carp;

use constant BABBLE => defined eval { require Digest::BubbleBabble };

eval { require Digest::SHA };		## optional for simple Net::DNS RR
eval { require Digest::GOST };
eval { require Digest::GOST::CryptoPro };

my %digest = (
	'1' => ['Digest::SHA', 1],
	'2' => ['Digest::SHA', 256],
	'3' => ['Digest::GOST::CryptoPro'],
	'4' => ['Digest::SHA', 384],
	);

#
# source: http://www.iana.org/assignments/dns-sec-alg-numbers
#
{
	my @algbyname = (
		'DELETE'	     => 0,			# [RFC4034][RFC4398][RFC8078]
		'RSAMD5'	     => 1,			# [RFC3110][RFC4034]
		'DH'		     => 2,			# [RFC2539]
		'DSA'		     => 3,			# [RFC3755][RFC2536]
					## Reserved	=> 4,	# [RFC6725]
		'RSASHA1'	     => 5,			# [RFC3110][RFC4034]
		'DSA-NSEC3-SHA1'     => 6,			# [RFC5155]
		'RSASHA1-NSEC3-SHA1' => 7,			# [RFC5155]
		'RSASHA256'	     => 8,			# [RFC5702]
					## Reserved	=> 9,	# [RFC6725]
		'RSASHA512'	     => 10,			# [RFC5702]
					## Reserved	=> 11,	# [RFC6725]
		'ECC-GOST'	     => 12,			# [RFC5933]
		'ECDSAP256SHA256'    => 13,			# [RFC6605]
		'ECDSAP384SHA384'    => 14,			# [RFC6605]
		'ED25519'	     => 15,			# [RFC8080]
		'ED448'		     => 16,			# [RFC8080]

		'INDIRECT'   => 252,				# [RFC4034]
		'PRIVATEDNS' => 253,				# [RFC4034]
		'PRIVATEOID' => 254,				# [RFC4034]
					## Reserved	=> 255,	# [RFC4034]
		);

	my %algbyval = reverse @algbyname;

	foreach (@algbyname) { s/[\W_]//g; }			# strip non-alphanumerics
	my @algrehash = map { /^\d/ ? ($_) x 3 : uc($_) } @algbyname;
	my %algbyname = @algrehash;				# work around broken cperl

	sub _algbyname {
		my $arg = shift;
		my $key = uc $arg;				# synthetic key
		$key =~ s/[\W_]//g;				# strip non-alphanumerics
		my $val = $algbyname{$key};
		return $val if defined $val;
		return $key =~ /^\d/ ? $arg : croak qq[unknown algorithm "$arg"];
	}

	sub _algbyval {
		my $value = shift;
		return $algbyval{$value} || return $value;
	}
}

#
# source: http://www.iana.org/assignments/ds-rr-types
#
{
	my @digestbyname = (
		'SHA-1'		  => 1,				# [RFC3658]
		'SHA-256'	  => 2,				# [RFC4509]
		'GOST-R-34.11-94' => 3,				# [RFC5933]
		'SHA-384'	  => 4,				# [RFC6605]
		);

	my @digestalias = (
		'SHA'  => 1,
		'GOST' => 3,
		);

	my %digestbyval = reverse @digestbyname;

	foreach (@digestbyname) { s/[\W_]//g; }			# strip non-alphanumerics
	my @digestrehash = map { /^\d/ ? ($_) x 3 : uc($_) } @digestbyname;
	my %digestbyname = ( @digestalias, @digestrehash );	# work around broken cperl

	sub _digestbyname {
		my $arg = shift;
		my $key = uc $arg;				# synthetic key
		$key =~ s/[\W_]//g;				# strip non-alphanumerics
		my $val = $digestbyname{$key};
		return $val if defined $val;
		return $key =~ /^\d/ ? $arg : croak qq[unknown algorithm "$arg"];
	}

	sub _digestbyval {
		my $value = shift;
		return $digestbyval{$value} || return $value;
	}
}


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $rdata = substr $$data, $offset, $self->{rdlength};
	@{$self}{qw(keytag algorithm digtype digestbin)} = unpack 'n C2 a*', $rdata;
	return;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return pack 'n C2 a*', @{$self}{qw(keytag algorithm digtype digestbin)};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	$self->_annotation( $self->babble ) if BABBLE && $self->{algorithm};
	my @param = @{$self}{qw(keytag algorithm digtype)};
	my @rdata = ( @param, split /(\S{64})/, $self->digest || '-' );
	return @rdata;
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	my $keytag = shift;		## avoid destruction by CDS algorithm(0)
	$self->algorithm(shift);
	$self->keytag($keytag);
	$self->digtype(shift);
	$self->digest(@_);
	return;
}


sub keytag {
	my $self = shift;

	$self->{keytag} = 0 + shift if scalar @_;
	return $self->{keytag} || 0;
}


sub algorithm {
	my ( $self, $arg ) = @_;

	unless ( ref($self) ) {		## class method or simple function
		my $argn = pop;
		return $argn =~ /[^0-9]/ ? _algbyname($argn) : _algbyval($argn);
	}

	return $self->{algorithm} unless defined $arg;
	return _algbyval( $self->{algorithm} ) if uc($arg) eq 'MNEMONIC';
	return $self->{algorithm} = _algbyname($arg) || die _algbyname('')    # disallow algorithm(0)
}


sub digtype {
	my ( $self, $arg ) = @_;

	unless ( ref($self) ) {		## class method or simple function
		my $argn = pop;
		return $argn =~ /[^0-9]/ ? _digestbyname($argn) : _digestbyval($argn);
	}

	return $self->{digtype} unless defined $arg;
	return _digestbyval( $self->{digtype} ) if uc($arg) eq 'MNEMONIC';
	return $self->{digtype} = _digestbyname($arg) || die _digestbyname('')	  # disallow digtype(0)
}


sub digest {
	my $self = shift;
	return unpack "H*", $self->digestbin() unless scalar @_;
	return $self->digestbin( pack "H*", join "", map { /^"*([\dA-Fa-f]*)"*$/ || croak("corrupt hex"); $1 } @_ );
}


sub digestbin {
	my $self = shift;

	$self->{digestbin} = shift if scalar @_;
	return $self->{digestbin} || "";
}


sub babble {
	return BABBLE ? Digest::BubbleBabble::bubblebabble( Digest => shift->digestbin ) : '';
}


sub create {
	my $class = shift;
	my $keyrr = shift;
	my %args  = @_;

	my ($type) = reverse split '::', $class;

	croak "Unable to create $type record for non-zone key" unless $keyrr->zone;
	croak "Unable to create $type record for revoked key" if $keyrr->revoke;
	croak "Unable to create $type record for invalid key" unless $keyrr->protocol == 3;

	my $self = Net::DNS::RR->new(
		owner	  => $keyrr->owner,			# per definition, same as keyrr
		type	  => $type,
		class	  => $keyrr->class,
		ttl	  => $keyrr->{ttl},
		keytag	  => $keyrr->keytag,
		algorithm => $keyrr->algorithm,
		digtype	  => 1,					# SHA1 by default
		%args
		);

	my $arglist = $digest{$self->digtype};
	croak join ' ', 'digtype', $self->digtype('MNEMONIC'), 'not supported' unless $arglist;
	my ( $object, @argument ) = @$arglist;
	my $hash = $object->new(@argument);
	$hash->add( $keyrr->{owner}->canonical );
	$hash->add( $keyrr->_encode_rdata );
	$self->digestbin( $hash->digest );

	return $self;
}


sub verify {
	my ( $self, $key ) = @_;
	my $verify = Net::DNS::RR::DS->create( $key, ( digtype => $self->digtype ) );
	return $verify->digestbin eq $self->digestbin;
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = Net::DNS::RR->new('name DS keytag algorithm digtype digest');

    use Net::DNS::SEC;
    $ds = Net::DNS::RR::DS->create(
	$dnskeyrr,
	digtype => 'SHA256',
	ttl	=> 3600
	);

=head1 DESCRIPTION

Class for DNS Delegation Signer (DS) resource record.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 keytag

    $keytag = $rr->keytag;
    $rr->keytag( $keytag );

The 16-bit numerical key tag of the key. (RFC2535 4.1.6)

=head2 algorithm

    $algorithm = $rr->algorithm;
    $rr->algorithm( $algorithm );

Decimal representation of the 8-bit algorithm field.

algorithm() may also be invoked as a class method or simple function
to perform mnemonic and numeric code translation.

=head2 digtype

    $digtype = $rr->digtype;
    $rr->digtype( $digtype );

Decimal representation of the 8-bit digest type field.

digtype() may also be invoked as a class method or simple function
to perform mnemonic and numeric code translation.

=head2 digest

    $digest = $rr->digest;
    $rr->digest( $digest );

Hexadecimal representation of the digest over the label and key.

=head2 digestbin

    $digestbin = $rr->digestbin;
    $rr->digestbin( $digestbin );

Binary representation of the digest over the label and key.

=head2 babble

    print $rr->babble;

The babble() method returns the 'BubbleBabble' representation of the
digest if the Digest::BubbleBabble package is available, otherwise
an empty string is returned.

BubbleBabble represents a message digest as a string of plausible
words, to make the digest easier to verify.  The "words" are not
necessarily real words, but they look more like words than a string
of hex characters.

The 'BubbleBabble' string is appended as a comment when the string
method is called.

=head2 create

    use Net::DNS::SEC;

    $dsrr = Net::DNS::RR::DS->create($keyrr, digtype => 'SHA-256' );
    $keyrr->print;
    $dsrr->print;

This constructor takes a key object as argument and will return the
corresponding DS RR object.

The digest type defaults to SHA-1.

=head2 verify

    $verify = $dsrr->verify($keyrr);

The boolean verify method will return true if the hash over the key
RR provided as the argument conforms to the data in the DS itself
i.e. the DS points to the DNSKEY from the argument.


=head1 COPYRIGHT

Copyright (c)2001-2005 RIPE NCC.  Author Olaf M. Kolkman

Portions Copyright (c)2013 Dick Franks.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC4034, RFC3658

L<Algorithm Numbers|http://www.iana.org/assignments/dns-sec-alg-numbers>,
L<Digest Types|http://www.iana.org/assignments/ds-rr-types>

=cut
