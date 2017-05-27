package Net::DNS::Resolver::os390;

#
# $Id$
#
our $VERSION = (qw$LastChangedRevision$)[1];


=head1 NAME

Net::DNS::Resolver::os390 - IBM OS/390 resolver class

=cut


use strict;
use warnings;
use base qw(Net::DNS::Resolver::Base);

use constant UTIL  => defined eval 'require Scalar::Util';
use constant UNCND => $] < 5.008;	## eval '${^TAINT}' breaks old compilers
use constant TAINT => UTIL && ( UNCND || eval '${^TAINT}' );


my $sysname = eval {
	$ENV{'PATH'} = '/bin:/usr/bin' if TAINT;
	open( HANDLE, 'sysvar SYSNAME |' ) or die $!;
	local $_ = <HANDLE>;
	close HANDLE;
	chomp;
	return $_;
} || '';


my @dataset = (				## plausible places to seek resolver configuration
	$ENV{RESOLVER_CONFIG},					# MVS dataset or Unix file name
	'/etc/resolv.conf',
	'//TCPIP.DATA',						# <username>.TCPIP.DATA
	"//'${sysname}.TCPPARMS(TCPDATA)'",
	"//'SYS1.TCPPARMS(TCPDATA)'",
	"//'TCPIP.TCPIP.DATA'"
	);


my $dotfile = '.resolv.conf';
my @dotpath = grep defined, $ENV{HOME}, '.';
my @dotfile = grep -f $_ && -o _, map "$_/$dotfile", @dotpath;


my %option = (				## map MVS config option names
	NSPORTADDR	   => 'port',
	RESOLVERTIMEOUT	   => 'retrans',
	RESOLVERUDPRETRIES => 'retry',
	SORTLIST	   => 'sortlist',
	);


sub _init {
	my $defaults = shift->_defaults;

	foreach my $dataset ( Net::DNS::Resolver::Base::_untaint(@dataset) ) {
		last if scalar eval {
			local *FILE;				# "cat" able to read MVS dataset
			open( FILE, qq[cat "$dataset" 2>/dev/null |] ) or die "$dataset: $!";

			my $qual = $dataset =~ m!^//[']?\w+[.]\w+!;

			my @nameserver;
			my @searchlist;
			local $_;

			while (<FILE>) {
				s/[;#].*$//;			# strip comment
				s/^\s+//;			# strip leading white space
				next unless $_;			# skip empty line

				next if $qual && m/^\w+:\w+/ && !m/^$sysname:/oi;


				m/^(\w+:)?(NSINTERADDR|nameserver)/i && do {
					my ( $keyword, @ip ) = grep defined, split;
					push @nameserver, @ip;
					next;
				};


				m/^(\w+:)?(DOMAINORIGIN|domain)/i && do {
					my ( $keyword, $domain ) = grep defined, split;
					$defaults->domain($domain);
					next;
				};


				m/^(\w+:)?search/i && do {
					my ( $keyword, @domain ) = grep defined, split;
					push @searchlist, @domain;
					next;
				};


				m/^(\w+:)?option/i && do {
					my ( $keyword, @option ) = grep defined, split;
					foreach (@option) {
						$defaults->_option( split m/:/ );
					}
					next;
				};


				m/^(\w+:)?RESOLVEVIA/i && do {
					my ( $keyword, $value ) = grep defined, split;
					$defaults->_option( 'usevc', $value eq 'TCP' );
					next;
				};


				m/^(\w+:)?(\w+)\s/ && do {
					my $attribute = $option{uc $2} || next;
					my ( $keyword, @value ) = grep defined, split;
					$defaults->_option( $attribute, @value );
				};
			}

			close(FILE);

			$defaults->searchlist(@searchlist) if @searchlist;
			$defaults->nameserver(@nameserver) if @nameserver;
		};
		warn $@ if $@;
	}

	%$defaults = Net::DNS::Resolver::Base::_untaint(%$defaults);

	map $defaults->_read_config_file($_), @dotfile;

	$defaults->_read_env;
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS::Resolver;

=head1 DESCRIPTION

This class implements the OS specific portions of C<Net::DNS::Resolver>.

No user serviceable parts inside, see L<Net::DNS::Resolver>
for all your resolving needs.

=head1 COPYRIGHT

Copyright (c)2017 Dick Franks.

All rights reserved.

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

L<perl>, L<Net::DNS>, L<Net::DNS::Resolver>

=cut

