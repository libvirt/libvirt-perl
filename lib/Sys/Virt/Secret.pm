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

Sys::Virt::Secret - Represent & manage a libvirt secret

=head1 DESCRIPTION

The C<Sys::Virt::Secret> module represents a secret managed
by the virtual machine monitor.

=head1 METHODS

=over 4

=cut

package Sys::Virt::Secret;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $con = exists $params{connection} ? $params{connection} : die "connection parameter is requried";
    my $self;
    if (exists $params{usageID} ||
	exists $params{usageType}) {
	die "usageID parameter must be provided with usageType" unless exists $params{usageID};
	die "usageType parameter must be provided with usageID" unless exists $params{usageType};
	$self = Sys::Virt::Secret::_lookup_by_usage($con,  $params{usageType}, $params{usageID});
    } elsif (exists $params{uuid}) {
	if (length($params{uuid}) == 16) {
	    $self = Sys::Virt::Secret::_lookup_by_uuid($con,  $params{uuid});
	} elsif (length($params{uuid}) == 32 ||
		 length($params{uuid}) == 36) {
	    $self = Sys::Virt::Secret::_lookup_by_uuid_string($con,  $params{uuid});
	} else {
	    die "UUID must be either 16 unsigned bytes, or 32/36 hex characters long";
	}
    } elsif (exists $params{xml}) {
	$self = Sys::Virt::Secret::_define_xml($con,  $params{xml});
    } else {
	die "usageID, xml or uuid parameters are required";
    }

    bless $self, $class;

    return $self;
}


=item my $uuid = $sec->get_uuid()

Returns a 16 byte long string containing the raw globally unique identifier
(UUID) for the secret.

=item my $uuid = $sec->get_uuid_string()

Returns a printable string representation of the raw UUID, in the format
'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'.

=item my $type = $sec->get_usage_type()

Returns the usage type of this secret. The usage type determines the
format of the unique identifier for this secret.

=item my $id = $sec->get_usage_id()

Returns the identifier of the object with which the secret is to
be used. For secrets with a usage type of volume, the identifier
is the fully qualfied path.

=item my $xml = $sec->get_xml_description()

Returns an XML document containing a complete description of
the secret's configuration

=item $sec->undefine()

Remove the configuration associated with a secret previously defined
with the C<define_secret> method in L<Sys::Virt>.

=item $bytes = $sec->get_value()

Returns the raw bytes for the value of this secret, or undef if
there is no value stored with the secret.

=item $sec->set_value($bytes)

Sets the value for the secret to be C<$bytes>.

=back

=head1 CONSTANTS

=over 4

=item Sys::Virt::Secret::USAGE_TYPE_NONE

The constant for secrets which are not assigned for use with a
particular object

=item Sys::Virt::Secret::USAGE_TYPE_VOLUME

The constant for secrets which are to be used for storage
volume encryption. The usage ID for secrets will refer to
the fully qualified volume path.

=cut


1;

=back

=head1 AUTHORS

Daniel P. Berrange <berrange@redhat.com>

=head1 COPYRIGHT

Copyright (C) 2006-2009 Red Hat
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
