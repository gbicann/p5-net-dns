package Net::DNS::Resolver::os2;

#
# $Id$
#
use vars qw($VERSION);
$VERSION = (qw$LastChangedRevision$)[1];


=head1 NAME

Net::DNS::Resolver::os2 - OS2 resolver class

=cut


use strict;
use base qw(Net::DNS::Resolver::Base);


my $config_dir	= $ENV{ETC} || '/etc';
my $resolv_conf = "$config_dir/resolv";
my $dotfile	= '.resolv.conf';

my @resolv_conf = grep -f $_ && -r _, $resolv_conf;

my @config_path;
push( @config_path, $ENV{HOME} ) if exists $ENV{HOME};
push( @config_path, '.' );

my @config_file = grep -f $_ && -o _, map "$_/$dotfile", @config_path;


sub _untaint {
	map { m/^(.*)$/; $1 } grep defined, @_;
}


sub _init {
	my $defaults = shift->_defaults;

	foreach (@resolv_conf) {
		$defaults->_read_config_file($_);
	}

	foreach my $attr (qw(nameservers searchlist)) {
		$defaults->$attr( _untaint $defaults->$attr() );
	}

	foreach (@config_file) {
		$defaults->_read_config_file($_);
	}

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

Copyright (c)2012 Dick Franks.

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

