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

Sys::Virt::DomainSnapshot - Represent & manage a libvirt guest domain

=head1 DESCRIPTION

The C<Sys::Virt::DomainSnapshot> module represents a guest domain managed
by the virtual machine monitor.

=head1 METHODS

=over 4

=cut

package Sys::Virt::DomainSnapshot;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $dom = exists $params{domain} ? $params{domain} : die "domain parameter is required";
    my $self;
    if (exists $params{name}) {
	$self = Sys::Virt::DomainSnapshot::_lookup_by_name($dom,  $params{name});
    } elsif (exists $params{xml}) {
	$self = Sys::Virt::DomainSnapshot::_create_xml($dom,  $params{xml});
    } else {
	die "name or xml parameters are required";
    }

    bless $self, $class;

    return $self;
}

=item my $xml = $dom->get_xml_description()

Returns an XML document containing a complete description of
the domain's configuration

=item $dom->delete()

Deletes this snapshot object & its datra

=item $dom->revert_to()

Revert the domain to the state associated with this snapshot

=cut

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
