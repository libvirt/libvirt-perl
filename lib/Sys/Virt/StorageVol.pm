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

Sys::Virt::StorageVol - Represent & manage a libvirt storage volume

=head1 DESCRIPTION

The C<Sys::Virt::StorageVol> module represents a storage volume managed
by libvirt. A storage volume is always associated with a containing
storage pool (C<Sys::Virt::StoragePool>).

=head1 METHODS

=over 4

=cut

package Sys::Virt::StorageVol;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $self;
    if (exists $params{name}) {
	my $pool = exists $params{pool} ? $params{pool} : die "pool parameter is requried";
	$self = Sys::Virt::StorageVol::_lookup_by_name($pool,  $params{name});
    } elsif (exists $params{key}) {
	my $con = exists $params{connection} ? $params{connection} : die "connection parameter is requried";
	$self = Sys::Virt::StorageVol::_lookup_by_key($con,  $params{key});
    } elsif (exists $params{path}) {
	my $con = exists $params{connection} ? $params{connection} : die "connection parameter is requried";
	$self = Sys::Virt::StorageVol::_lookup_by_path($con,  $params{path});
    } elsif (exists $params{xml}) {
	my $pool = exists $params{pool} ? $params{pool} : die "pool parameter is requried";
	if ($params{clone}) {
	    $self = Sys::Virt::StorageVol::_create_xml_from($pool,  $params{xml}, $params{clone}, 0);
	} else {
	    $self = Sys::Virt::StorageVol::_create_xml($pool,  $params{xml}, 0);
	}
    } else {
	die "name, key, path or xml parameters are required";
    }

    bless $self, $class;

    return $self;
}


=item my $name = $vol->get_name()

Returns a string with a locally unique name of the storage vol

=item my $name = $vol->get_key()

Returns a string with a globally unique key for the storage vol

=item my $name = $vol->get_path()

Returns a string with a locally unique file path of the storage vol

=item my $xml = $vol->get_xml_description()

Returns an XML document containing a complete description of
the storage vol's configuration

=item $vol->delete($flags)

Immediately delete the storage volume freeing its storage resources.
The C<flags> parameter indicates any special action to be taken when
deleting the volume.

=item my %info = $vol->get_info()

Retrieve live information about the storage volume. The returned
C<%info> hash contains three keys. C<type> indicates whether the
volume is a file or block device. C<capacity> provides the maximum
logical size of the volume. C<allocation> provides the current
physical usage of the volume. The allocation may be less than the
capacity for sparse, or grow-on-demand volumes. The allocation
may also be larger than the capacity, if there is a metadata overhead
for the volume format.

=back

=head1 CONSTANTS

The following sets of constants are useful when dealing with storage
volumes

=head2 VOLUME TYPES

The following constants are useful for interpreting the C<type>
field in the hash returned by the C<get_info> method

=over 4

=item Sys::Virt::StorageVol::TYPE_FILE

The volume is a plain file

=item Sys::Virt::StorageVol::TYPE_BLOCK

The volume is a block device

=back

=head2 DELETE MODES

The following constants are useful for the C<flags> parameter of
the C<delete> method

=over 4

=item Sys::Virt::StorageVol::DELETE_NORMAL

Do a plain delete without any attempt to scrub data.

=item Sys::Virt::StorageVol::DELETE_ZEROED

Zero out current allocated blocks when deleteing the volume

=back

=cut


1;

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
