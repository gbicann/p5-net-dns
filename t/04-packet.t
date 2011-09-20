# $Id$	-*-perl-*-

use Test::More tests => 78;
use strict;

use Net::DNS;


#	new() class constructor method must return object of appropriate class
isa_ok(Net::DNS::Packet->new(),	'Net::DNS::Packet',	'new() object');


#	string method returns character string representation of object
like(Net::DNS::Packet->new()->string,	'/HEADER/',	'$packet->string' );


#	Create a DNS query packet
my ($domain, $type, $class) = qw(example.test MX IN);
my $question = Net::DNS::Question->new($domain, $type, $class);

my $packet = Net::DNS::Packet->new($domain, $type, $class);
like($packet->string,	"/$class\t$type/",	'create query packet' );

ok($packet->header,	'packet->header() method works');
ok($packet->header->isa('Net::DNS::Header'),	'header() returns header object');

my @question = $packet->question;
ok(@question && @question == 1,		'packet->question() returns single element list');
my ($q) = @question;
ok($q->isa('Net::DNS::Question'),	'list element is a question object');
is($q->string,	$question->string,	'question object correct');


#	Empty packet created when new() arguments omitted
my $empty = Net::DNS::Packet->new();
ok($empty,	'create empty packet' );
foreach my $method ( qw(question answer authority additional) ) {
	my @result = $empty->$method;
	ok(@result == 0,	"$method() returns empty list");
}

#	Default question added to empty packet
my $default = Net::DNS::Question->new(qw(. ANY ANY));
ok($empty->data,	'packet->data() method works');
my ($implicit) = $empty->question;
is($implicit->string,	$default->string,	'implicit question in empty packet' );


#	new(\$data) class constructor method returns object of appropriate class
my $packet_data = $packet->data;
my $packet2 = Net::DNS::Packet->new(\$packet_data);
isa_ok($packet2,	'Net::DNS::Packet',	'new(\$data) object');
is($packet2->string, $packet->string, 'decoded packet matches original');


#	new(\$data) class constructor raises exception when data truncated
my @data = unpack 'C*', $packet->data;
while ( @data ) {
	pop(@data);
	my $truncated = pack 'C*', @data;
	my ($object,$error) = eval{ Net::DNS::Packet->new(\$truncated) };
	my $length = length $truncated;
	chomp $error;
	ok($error,	"truncated ($length octets):\t$error");
}


#	Use push() to add RRs to each section
my $update = Net::DNS::Packet->new('.');
my $index;
foreach my $section ( qw(answer authority additional) ) {
	my $i = ++$index;
	my $rr1 = Net::DNS::RR->new(	Name	=> "$section$i.example.test",
					Type	=> "A",
					Address	=> "10.0.0.$i"
					);
	my $string1 = $rr1->string;
	my $count1 = $update->push($section, $rr1);
	like($update->string,	"/$string1/",	"push first RR into $section section");
	is($count1,	1,	"push() returns $section RR count");

	my $j = ++$index;
	my $rr2 = Net::DNS::RR->new(	Name	=> "$section$j.example.test",
					Type	=> "A",
					Address	=> "10.0.0.$j"
					);
	my $string2 = $rr2->string;
	my $count2 = $update->push($section, $rr2);
	like($update->string,	"/$string2/",	"push second RR into $section section");
	is($count2,	2,	"push() returns $section RR count");
}

# Add enough distinct labels to render compression unusable at some point
for (0..255) {
    $update->push('answer',
		  Net::DNS::RR->new("X$_ TXT \"" . pack("A255", "x").'"'));
}
$update->push('answer', Net::DNS::RR->new('XY TXT ""'));
$update->push('answer', Net::DNS::RR->new('VW.XY TXT ""'));

#	Decode data buffer and compare with original
my $buffer = $update->data;
my $decoded = eval { Net::DNS::Packet->new(\$buffer) };
ok($decoded, 'new() from data buffer works');
foreach my $count ( qw(qdcount ancount nscount arcount) ) {
	is($decoded->header->$count, $update->header->$count, "check header->$count correct");
}


foreach my $section ( qw(question answer authority additional) ) {
	my @original = map{$_->string} $update->$section;
	my @content = map{$_->string} $decoded->$section;
	is_deeply(\@content, \@original, "check content of $section section");
}


#	check that pop() removes RR from section
foreach my $section ( qw(question answer authority additional) ) {
	my $c1 = $update->push($section);
	my $rr = $update->pop($section);
	my $c2 = $update->push($section);
	is($c2,	$c1-1,	"pop() RR from $section section");
}




#	Test using a predefined answer.
#	This is an answer that was generated by a bind server, with an option munged on the end.

my $BIND = pack('H*','22cc85000001000000010001056461636874036e657400001e0001c00c0006000100000e100025026e730472697065c012046f6c6166c02a7754e1ae0000a8c0000038400005460000001c2000002910000000800000050000000130');

my $bind = Net::DNS::Packet->new(\$BIND);

is($bind->header->qdcount, 1, 'check question count in synthetic packet header');
is($bind->header->ancount, 0, 'check answer count in synthetic packet header');
is($bind->header->nscount, 1, 'check authority count in synthetic packet header'); 
is($bind->header->adcount, 1, 'check additional count in synthetic packet header');

my ($rr) = $bind->additional;

is($rr->type,	'OPT',	'Additional section packet is EDNS0 type');
is($rr->class,	'4096',	'EDNS0 packet size correct');

