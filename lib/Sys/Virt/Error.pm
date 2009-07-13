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

Sys::Virt::Error - error object for libvirt APIs

=head1 DESCRIPTION

The C<Sys::Virt::Error> class provides an encoding of the
libvirt errors. Instances of this object can be thrown by
pretty much any of the Sys::Virt APIs.

=head1 METHODS

=over 4

=cut

package Sys::Virt::Error;

use strict;
use warnings;
use overload ('""' => 'stringify');

=item $err->stringify

Convert the object into string format suitable for printing on a
console to inform a user of the error.

=cut

sub stringify {
    my $self = shift;

    return "libvirt error code: " . $self->{code} . ", message: " . $self->{message} . ($self->{message} =~ /\n$/ ? "" : "\n");
}

=item my $code = $err->code

Return the raw error code represented by this error.

=cut

sub code {
    my $self = shift;
    return $self->{code}
}

=item my $from = $err->domain

Return the error domain raising this error.

=cut

sub domain {
    my $self = shift;
    return $self->{domain}
}

=item my $msg = $err->message

Return an informative message describing the error condition.

=cut

sub message {
    my $self = shift;
    return $self->{code}
}


1;

=back

=head1 CONSTANTS

=head2 ERROR DOMAINS

The error domain indicates which internal part of libvirt the error
report was raised from.

=over 4

=item Sys::Virt::Error::FROM_CONF

Configuration file handling

=item Sys::Virt::Error::FROM_DOM

Error while operating on a domain

=item Sys::Virt::Error::FROM_DOMAIN

Domain configuration handling

=item Sys::Virt::Error::FROM_LXC

LXC virtualization driver

=item Sys::Virt::Error::FROM_NET

Error while operating on a network

=item Sys::Virt::Error::FROM_NETWORK

Network configuration handling

=item Sys::Virt::Error::FROM_NODEDEV

Node device configuration handling

=item Sys::Virt::Error::FROM_NONE

No specific error domain.

=item Sys::Virt::Error::FROM_OPENVZ

OpenVZ virtualization driver

=item Sys::Virt::Error::FROM_PROXY

Xen proxy virtualization driver

=item Sys::Virt::Error::FROM_QEMU

QEMU virtualization driver

=item Sys::Virt::Error::FROM_REMOTE

Remote client virtualization driver

=item Sys::Virt::Error::FROM_RPC

XML-RPC handling code

=item Sys::Virt::Error::FROM_SECURITY

Security services driver

=item Sys::Virt::Error::FROM_SEXPR

SEXPR parsing code

=item Sys::Virt::Error::FROM_STATS_LINUX

Device statistics code

=item Sys::Virt::Error::FROM_STORAGE

Storage configuration handling

=item Sys::Virt::Error::FROM_TEST

Test virtualization driver

=item Sys::Virt::Error::FROM_UML

UML virtualization driver

=item Sys::Virt::Error::FROM_XEN

Xen hypervisor driver

=item Sys::Virt::Error::FROM_XEND

XenD daemon driver

=item Sys::Virt::Error::FROM_XENSTORE

XenStore driver

=item Sys::Virt::Error::FROM_XENXM

Xen XM configuration file driver

=item Sys::Virt::Error::FROM_XEN_INOTIFY

Xen Inotify events driver

=item Sys::Virt::Error::FROM_XML

Low level XML parser

=back

=head2 ERROR CODES

The error codes allow for specific problems to be identified and
handled separately from generic error handling.

=over 4

=item Sys::Virt::Error::ERR_AUTH_FAILED

Authentication falure when connecting to a driver

=item Sys::Virt::Error::ERR_CALL_FAILED

Operation not supported by driver (DEPRECATED & unused)

=item Sys::Virt::Error::ERR_CONF_SYNTAX

Configuration file syntax error

=item Sys::Virt::Error::ERR_DOM_EXIST

The domain already exists

=item Sys::Virt::Error::ERR_DRIVER_FULL

Too many hypervisor drivers have been registered

=item Sys::Virt::Error::ERR_GET_FAILED

HTTP GET command failed talking to XenD

=item Sys::Virt::Error::ERR_GNUTLS_ERROR

GNUTLS encryption error in RPC driver

=item Sys::Virt::Error::ERR_HTTP_ERROR

Unexpected HTTP error code from XenD

=item Sys::Virt::Error::ERR_INTERNAL_ERROR

Generic internal error

=item Sys::Virt::Error::ERR_INVALID_ARG

Invalid argument supplied to function

=item Sys::Virt::Error::ERR_INVALID_CONN

Invalid connection object

=item Sys::Virt::Error::ERR_INVALID_DOMAIN

Invalid domain object

=item Sys::Virt::Error::ERR_INVALID_MAC

Invalid MAC address string

=item Sys::Virt::Error::ERR_INVALID_NETWORK

Invalid network object

=item Sys::Virt::Error::ERR_INVALID_NODE_DEVICE

Invalid node device object

=item Sys::Virt::Error::ERR_INVALID_STORAGE_POOL

Invalid storage pool object

=item Sys::Virt::Error::ERR_INVALID_STORAGE_VOL

Invalid storage vol object

=item Sys::Virt::Error::ERR_NETWORK_EXIST

Network with this name/uuid already exists

=item Sys::Virt::Error::ERR_NO_CONNECT

Unable to connect to requested hypervisor driver

=item Sys::Virt::Error::ERR_NO_DEVICE

Missing device information

=item Sys::Virt::Error::ERR_NO_DOMAIN

No such domain with that name/uuid/id

=item Sys::Virt::Error::ERR_NO_KERNEL

Missing kernel information in domain configuration

=item Sys::Virt::Error::ERR_NO_MEMORY

Missing memory information in domain configuration

=item Sys::Virt::Error::ERR_NO_NAME

Missing name in object configuration

=item Sys::Virt::Error::ERR_NO_NETWORK

No such network with that name/uuid

=item Sys::Virt::Error::ERR_NO_NODE_DEVICE

No such node device with that name

=item Sys::Virt::Error::ERR_NO_OS

Missing OS information in domain configuration

=item Sys::Virt::Error::ERR_NO_ROOT

Missing root device information in domain configuration

=item Sys::Virt::Error::ERR_NO_SECURITY_MODEL

Missing security model information in domain configuratio

=item Sys::Virt::Error::ERR_NO_SOURCE

Missing source device information in domain configuration

=item Sys::Virt::Error::ERR_NO_STORAGE_POOL

No such storage pool with that name/uuid

=item Sys::Virt::Error::ERR_NO_STORAGE_VOL

No such storage volume with that name/path/key

=item Sys::Virt::Error::ERR_NO_SUPPORT

This operation is not supported by the active driver

=item Sys::Virt::Error::ERR_NO_TARGET

Missing target device information in domain configuration

=item Sys::Virt::Error::ERR_NO_XEN

Unable to connect to Xen hypervisor

=item Sys::Virt::Error::ERR_NO_XENSTORE

Unable to connect to XenStorage daemon

=item Sys::Virt::Error::ERR_OK

No error code. This should never be see

=item Sys::Virt::Error::ERR_OPEN_FAILED

Unable to open a configuration file

=item Sys::Virt::Error::ERR_OPERATIONED_DENIED

The operation is forbidden for the current connection

=item Sys::Virt::Error::ERR_OPERATION_FAILED

The operation failed to complete

=item Sys::Virt::Error::ERR_OS_TYPE

Missing/incorrect OS type in domain configuration

=item Sys::Virt::Error::ERR_PARSE_FAILED

Failed to parse configuration file

=item Sys::Virt::Error::ERR_POST_FAILED

HTTP POST failure talking to XenD

=item Sys::Virt::Error::ERR_READ_FAILED

Unable to read from configuration file

=item Sys::Virt::Error::ERR_RPC

Generic RPC error talking to XenD

=item Sys::Virt::Error::ERR_SEXPR_SERIAL

Failed to generic SEXPR for XenD

=item Sys::Virt::Error::ERR_SYSTEM_ERROR

Generic operating system error

=item Sys::Virt::Error::ERR_UNKNOWN_HOST

Unknown hostname

=item Sys::Virt::Error::ERR_WRITE_FAILED

Failed to write to configuration file

=item Sys::Virt::Error::ERR_XEN_CALL

Failure while talking to Xen hypervisor

=item Sys::Virt::Error::ERR_XML_DETAIL

Detailed XML parsing error

=item Sys::Virt::Error::ERR_XML_ERROR

Generic XML parsing error

=item Sys::Virt::Error::WAR_NO_NETWORK

Warning that no network driver is activated

=item Sys::Virt::Error::WAR_NO_NODE

Warning that no node device driver is activated

=item Sys::Virt::Error::WAR_NO_STORAGE

Warning that no storage driver is activated

=item Sys::Virt::Error::ERR_INVALID_INTERFACE

Invalid network interface object

=item Sys::Virt::Error::ERR_NO_INTERFACE

No interface with the matching name / mac address

=item Sys::Virt::Error::ERR_OPERATION_INVALID

The requested operation is not valid for the current object state

=item Sys::Virt::Error::WAR_NO_INTERFACE

The network interface driver is not available

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

L<Sys::Virt::Domain>, L<Sys::Virt>, C<http://libvirt.org>

=cut
