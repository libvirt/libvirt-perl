# -*- perl -*-
#
# Copyright (C) 2006 Red Hat
# Copyright (C) 2006-2007 Daniel P. Berrange
#
# This program is free software; You can redistribute it and/or modify
# it under either:
#
# a) the GNU General Public License as published by the Free
#   Software Foundation; either version 2, or (at your option) any
#   later version,
#
# or
#
# b) the "Artistic License"
#
# The file "LICENSE" distributed along with this file provides full
# details of the terms and conditions of the two licenses.

=pod

=head1 NAME

Sys::Virt::Network - Represent & manage a libvirt virtual network

=head1 DESCRIPTION

The C<Sys::Virt::Network> module represents a virtual network managed
by the virtual machine monitor.

=head1 METHODS

=over 4

=cut

package Sys::Virt::Network;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $con = exists $params{connection} ? $params{connection} : die "connection parameter is requried";
    my $self;
    if (exists $params{name}) {
	$self = Sys::Virt::Network::_lookup_by_name($con,  $params{name});
    } elsif (exists $params{uuid}) {
	if (len($params{uuid} == 16)) {
	    $self = Sys::Virt::Network::_lookup_by_uuid($con,  $params{uuid});
	} elsif (len($params{uuid} == 32) ||
		 len($params{uuid} == 36)) {
	    $self = Sys::Virt::Network::_lookup_by_uuid_striing($con,  $params{uuid});
	} else {
	    die "UUID must be either 16 unsigned bytes, or 32/36 hex characters long";
	}
    } elsif (exists $params{xml}) {
	if ($params{nocreate}) {
	    $self = Sys::Virt::Network::_define_xml($con,  $params{xml});
	} else {
	    $self = Sys::Virt::Network::_create_linux($con,  $params{xml});
	}
    } else {
	die "address, id or uuid parameters are required";
    }

    bless $self, $class;

    return $self;
}


=item my $uuid = $net->get_uuid()

Returns a 16 byte long string containing the raw globally unique identifier
(UUID) for the network.

=item my $uuid = $net->get_uuid_string()

Returns a printable string representation of the raw UUID, in the format
'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'.

=item my $name = $net->get_name()

Returns a string with a locally unique name of the network

=item my $xml = $net->get_xml_description()

Returns an XML document containing a complete description of
the network's configuration

=item $net->create()

Start a network whose configuration was previously defined using the
C<define_network> method in L<Sys::Virt>.

=item $net->undefine()

Remove the configuration associated with a network previously defined
with the C<define_network> method in L<Sys::Virt>. If the network is
running, you probably want to use the C<shutdown> or C<destroy>
methods instead.

=item $net->destroy()

Immediately terminate the machine, and remove it from the virtual
machine monitor. The C<$net> handle is invalid after this call
completes and should not be used again.

=item $net->get_bridge_name()

Return the name of the bridge device associated with the virtual
network

=cut


sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    die "&Sys::Virt::Network::constant not defined" if $constname eq '_constant';
    if (!exists $Sys::Virt::Network::_constants{$constname}) {
	die "no such constant \$" . __PACKAGE__ . "::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Sys::Virt::Network::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}


1;

=back

=head1 AUTHORS

Daniel P. Berrange <berrange@redhat.com>

=head1 COPYRIGHT

Copyright (C) 2006 Red Hat
Copyright (C) 2006-2007 Daniel P. Berrange

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of either the GNU General Public License as published
by the Free Software Foundation (either version 2 of the License, or at
your option any later version), or, the Artistic License, as specified
in the Perl README file.

=head1 SEE ALSO

L<Sys::Virt>, L<Sys::Virt::Error>, C<http://libvirt.org>

=cut
