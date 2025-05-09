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

    my $con = exists $params{connection} ? $params{connection} : die "connection parameter is required";
    my $self;
    if (exists $params{name}) {
	$self = Sys::Virt::NodeDevice::_lookup_by_name($con,  $params{name});
    } elsif (exists $params{wwnn}) {
	$self = Sys::Virt::NodeDevice::_lookup_scsihost_by_wwn($con,
							       $params{wwnn},
							       $params{wwpn},
							       $params{flags});
    } elsif (exists $params{xml}) {
	if ($params{nocreate}) {
	    $self = Sys::Virt::NodeDevice::_define_xml($con, $params{xml}, $params{flags});
	} else {
	    $self = Sys::Virt::NodeDevice::_create_xml($con, $params{xml}, $params{flags});
	}
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

=item my $xml = $dev->get_xml_description($flags=0)

Returns an XML document containing a complete description of the node
device's configuration. The optional $flags parameter controls
generation of the XML document, defaulting to 0 if omitted. It can be
one or more of the XML DUMP constants listed later in this document.

=item $dev->reattach()

Rebind the node device to the host OS device drivers.

=item $dev->dettach()

Unbind the node device from the host OS device driver

=item $dev->reset()

Reset the node device. The device must be unbound from the host
OS drivers for this to work

=item $dev->create($flags=0)

Start a node device whose configuration was previously defined using the
C<define_node_device> method in L<Sys::Virt>. The C<$flags> parameter is
currently unused and defaults to zero.

=item $dev->undefine($flags=0)

Delete a node device whose configuration was previously defined using the
C<define_node_device> method in L<Sys::Virt>. The C<$flags> parameter is
currently unused and defaults to zero.

=item $flag = $dev->get_autostart();

Return a true value if the node device is configured to automatically
start upon boot. Return false, otherwise

=item $dev->set_autostart($flag)

Set the state of the autostart flag, which determines whether the
node device will automatically start upon boot of the host OS.

=item $dev->is_active()

Returns a true value if the node device is currently running

=item $dev->is_persistent()

Returns a true value if the node device has a persistent configuration
file defined

=item $dev->destroy()

Destroy the virtual device releasing any OS resources associated
with it.

=item my @caps = $dev->list_capabilities()

Return a list of all capabilities in the device.

=item $dev->update($xml, $flags=0)

Update the definition of an existing node device with C<$xml>. The
C<$flags> parameter can be use to control which config is affected
(see XML UPDATE FLAGS) and defaults to zero (affect current state of
the node device).

=back

=head1 CONSTANTS

This section documents constants that are used with various
APIs described above

=head2 LIST FILTERING

The following constants are used to filter object lists

=over 4

=item Sys::Virt::NodeDevice::LIST_CAP_NET

Include devices with the network capability

=item Sys::Virt::NodeDevice::LIST_CAP_PCI_DEV

Include devices with the PCI device capability

=item Sys::Virt::NodeDevice::LIST_CAP_SCSI

Include devices with the SCSI capability

=item Sys::Virt::NodeDevice::LIST_CAP_SCSI_HOST

Include devices with the SCSI host capability

=item Sys::Virt::NodeDevice::LIST_CAP_SCSI_TARGET

Include devices with the SCSI target capability

=item Sys::Virt::NodeDevice::LIST_CAP_STORAGE

Include devices with the storage capability

=item Sys::Virt::NodeDevice::LIST_CAP_SYSTEM

Include devices with the system capability

=item Sys::Virt::NodeDevice::LIST_CAP_USB_DEV

Include devices with the USB device capability

=item Sys::Virt::NodeDevice::LIST_CAP_USB_INTERFACE

Include devices with the USB interface capability

=item Sys::Virt::NodeDevice::LIST_CAP_FC_HOST

Include devices with the fibre channel host capability

=item Sys::Virt::NodeDevice::LIST_CAP_VPORTS

Include devices with the NPIV vport capability

=item Sys::Virt::NodeDevice::LIST_CAP_SCSI_GENERIC

Include devices with the SCSI generic capability

=item Sys::Virt::NodeDevice::LIST_CAP_DRM

Include devices with the DRM capability

=item Sys::Virt::NodeDevice::LIST_CAP_MDEV

Include mediated devices

=item Sys::Virt::NodeDevice::LIST_CAP_MDEV_TYPES

Include devices capable of mediated devices

=item Sys::Virt::NodeDevice::LIST_CAP_CCW_DEV

Include CCW devices

=item Sys::Virt::NodeDevice::LIST_CAP_CSS_DEV

Include CSS devices

=item Sys::Virt::NodeDevice::LIST_CAP_VDPA

Include VDPA devices

=item Sys::Virt::NodeDevice::LIST_CAP_AP_CARD

Include s390 AP card devices

=item Sys::Virt::NodeDevice::LIST_CAP_AP_MATRIX

Include s390 AP matrix devices

=item Sys::Virt::NodeDevice::LIST_CAP_AP_QUEUE

Include s390 AP queue devices

=item Sys::Virt::NodeDevice::LIST_CAP_VPD

Include PCI devices with VPD

=item Sys::Virt::NodeDevice::LIST_CAP_CCWGROUP_DEV

Include s390 CCW group devices

=item Sys::Virt::NodeDevice::LIST_CAP_CCWGROUP_MEMBER

Include s390 CCW group members

=item Sys::Virt::NodeDevice::LIST_ACTIVE

Include active devices

=item Sys::Virt::NodeDevice::LIST_INACTIVE

Include inactive devices

=item Sys::Virt::NodeDevice::LIST_PERSISTENT

Include persistent devices

=item Sys::Virt::NodeDevice::LIST_TRANSIENT

Include transient devices

=back

=head2 EVENT ID CONSTANTS

=over 4

=item Sys::Virt::NodeDevice::EVENT_ID_LIFECYCLE

Node device lifecycle events

=item Sys::Virt::NodeDevice::EVENT_ID_UPDATE

Node device config update events

=back

=head2 LIFECYCLE CHANGE EVENTS

The following constants allow node device lifecycle change events to be
interpreted. The events contain both a state change, and a
reason though the reason is currently unused.

=over 4

=item Sys::Virt::NodeDevice::EVENT_CREATED

Indicates that a device was created

=item Sys::Virt::NodeDevice::EVENT_DELETED

Indicates that a device has been deleted

=item Sys::Virt::NodeDevice::EVENT_DEFINED

Indicates that a device configuration has been created

=item Sys::Virt::NodeDevice::EVENT_UNDEFINED

Indicates that a device configuration has been deleted

=back

=head2 NODE DEVICE CREATION

=over 4

=item Sys::Virt::NodeDevice::CREATE_XML_VALIDATE

Validate the XML document against schema

=back

=head2 NODE DEVICE DEFINE

=over 4

=item Sys::Virt::NodeDevice::DEFINE_XML_VALIDATE

Validate the XML document against schema

=back

=head2 NODE DEVICE UPDATE

=over 4

=item Sys::Virt::NodeDevice::UPDATE_AFFECT_CURRENT

Affect live if node device is active, config if it's not active

=item Sys::Virt::NodeDevice::UPDATE_AFFECT_LIVE

Affect live state of node device only

=item Sys::Virt::NodeDevice::UPDATE_AFFECT_CONFIG

Affect persistent config only

=back

=head2 XML DUMP OPTIONS

The following constants are used to control the information
included in the XML configuration dump

=over 4

=item Sys::Virt::NodeDevice::XML_INACTIVE

Report the persistent inactive configuration for the node device.

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
