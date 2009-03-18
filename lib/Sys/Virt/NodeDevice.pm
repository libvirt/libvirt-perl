# -*- perl -*-
#
# Copyright (C) 2006-2009 Red Hat
# Copyright (C) 2006-2009 Daniel P. Berrange
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

Sys::Virt::NodeDevice - Represent & manage a libvirt storage pool

=head1 DESCRIPTION

The C<Sys::Virt::NodeDevice> module represents a storage pool managed
by libvirt. There are a variety of storage pool implementations for
LVM, Local directories/filesystems, network filesystems, disk
partitioning, iSCSI, and SCSI.

=head1 METHODS

=over 4

=cut

package Sys::Virt::NodeDevice;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $con = exists $params{connection} ? $params{connection} : die "connection parameter is requried";
    my $self;
    if (exists $params{name}) {
	$self = Sys::Virt::NodeDevice::_lookup_by_name($con,  $params{name});
    } else {
	die "name parameter is required";
    }

    bless $self, $class;

    return $self;
}


=item my $name = $dev->get_name()

Returns a string with a locally unique name of the device

=item my $parentname = $dev->get_parent()

Returns a string with a locally unique name of the parent
of the device, or undef if there is no parent

=item my $xml = $dev->get_xml_description()

Returns an XML document containing a complete description of
the storage dev's configuration

=item $dev->reattach()

Rebind the node device to the host OS device drivers.

=item $dev->dettach()

Unbind the node device from the host OS device driver

=item $dev->reset()

Reset the node device. The device must be unbound from the host
OS drivers for this to work

=item my @caps = $dev->list_capabilities()

Return a list of all capabilities in the device.

=cut


1;

=back

=head1 AUTHORS

Daniel P. Berrange <berrange@redhat.com>

=head1 COPYRIGHT

Copyright (C) 2006-2009 Red Hat
Copyright (C) 2006-2009 Daniel P. Berrange

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of either the GNU General Public License as published
by the Free Software Foundation (either version 2 of the License, or at
your option any later version), or, the Artistic License, as specified
in the Perl README file.

=head1 SEE ALSO

L<Sys::Virt>, L<Sys::Virt::Error>, C<http://libvirt.org>

=cut
