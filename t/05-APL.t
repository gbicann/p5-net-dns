#!/usr/bin/perl
# $Id$	-*-perl-*-
#

use strict;
use warnings;
use Test::More tests => 31;
use TestToolkit;

use Net::DNS;


my $name = 'APL.example';
my $type = 'APL';
my $code = 42;
my @attr = qw( aplist );
my @data = qw( 1:224.0.0.0/4 2:FF00::0/16 !1:192.168.38.0/28 1:224.0.0.0/0 2:FF00::0/0 );
my @also = qw( string negate family address );			# apitem attributes

my $wire = '00010401e000021001ff00011c83c0a8260001000000020000';

my $typecode = unpack 'xn', Net::DNS::RR->new( type => $type )->encode;
is( $typecode, $code, "$type RR type code = $code" );

my $hash = {};
@{$hash}{@attr} = @data;


for my $rr ( Net::DNS::RR->new( name => $name, type => $type, %$hash ) ) {
	my $string = $rr->string;
	my $rr2	   = Net::DNS::RR->new($string);
	is( $rr2->string, $string, 'new/string transparent' );

	is( $rr2->encode, $rr->encode, 'new($string) and new(%hash) equivalent' );

	foreach (@attr) {
		is( $rr->$_, $hash->{$_}, "expected result from rr->$_()" );
	}
}


for my $rr ( Net::DNS::RR->new("$name $type @data") ) {
	foreach my $item ( $rr->aplist ) {
		foreach (@also) {
			ok( defined( $item->$_ ), "aplist item->$_() attribute" );
		}
	}
}


{
	my $rr	    = Net::DNS::RR->new("$name $type @data");
	my $null    = Net::DNS::RR->new("$name NULL")->encode;
	my $empty   = Net::DNS::RR->new("$name $type")->encode;
	my $rxbin   = Net::DNS::RR->decode( \$empty )->encode;
	my $txtext  = Net::DNS::RR->new("$name $type")->string;
	my $rxtext  = Net::DNS::RR->new($txtext)->encode;
	my $encoded = $rr->encode;
	my $decoded = Net::DNS::RR->decode( \$encoded );
	my $hex1    = unpack 'H*', $encoded;
	my $hex2    = unpack 'H*', $decoded->encode;
	my $hex3    = unpack 'H*', substr( $encoded, length $null );
	is( $hex2,	     $hex1,	    'encode/decode transparent' );
	is( $hex3,	     $wire,	    'encoded RDATA matches example' );
	is( length($empty),  length($null), 'encoded RDATA can be empty' );
	is( length($rxbin),  length($null), 'decoded RDATA can be empty' );
	is( length($rxtext), length($null), 'string RDATA can be empty' );

	my @wire = unpack 'C*', $encoded;
	$wire[length($empty) - 1]--;
	my $wireformat = pack 'C*', @wire;
	exception( 'corrupt wire-format', sub { Net::DNS::RR->decode( \$wireformat ) } );
}


exception( 'unknown address family', sub { Net::DNS::RR->new("$name $type 0:0::0/0") } );

exit;


