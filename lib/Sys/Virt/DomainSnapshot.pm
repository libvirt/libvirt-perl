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
	$self = Sys::Virt::DomainSnapshot::_create_xml($dom,  $params{xml}, $params{flags} ? $params{flags} : 0);
    } else {
	die "name or xml parameters are required";
    }

    bless $self, $class;

    return $self;
}

=item my $xml = $domss->get_xml_description($flags)

Returns an XML document containing a complete description of
the domain's configuration.

=item $domss->delete($flags)

Deletes this snapshot object & its data. The optional C<$flags> parameter controls
what should be deleted via the C<Sys::Virt::DomainSnapshot::DELETE_*>
constants.

=item $domss->revert_to($flags)

Revert the domain to the state associated with this snapshot. The optional
C<$flags> control the state of the vm after the revert via the
C<Sys::Virt::DomainSnapshot::REVERT_*> constants.

=item $parentss = $domss->get_parent();

Return the parent of the snapshot, if any

=item $count = $domss->num_of_child_snapshots()

Return the number of saved snapshots which are children of this snapshot

=item @names = $domss->list_child_snapshot_names()

List the names of all saved snapshots which are children of this
snapshot . The names can be used with the C<lookup_snapshot_by_name>

=item @snapshots = $domss->list_child_snapshots()

Return a list of all snapshots that are children of this snapshot. The elements
in the returned list are instances of the L<Sys::Virt::DomainSnapshot> class.

=cut


sub list_child_snapshots {
    my $self = shift;

    my $nnames = $self->num_of_child_snapshots();
    my @names = $self->list_child_snapshot_names($nnames);

    my @snapshots;
    foreach my $name (@names) {
	eval {
	    push @snapshots, Sys::Virt::DomainSnapshot->_new(domain => $self, name => $name);
	};
	if ($@) {
	    # nada - snapshot went away before we could look it up
	};
    }
    return @snapshots;
}


=back

=head1 CONSTANTS

=head2 SNAPSHOT CREATION

The following constants are useful when creating snapshots

=over 4

=item Sys::Virt::DomainSnapshot::CREATE_CURRENT

Set the defined snapshot to be the current snapshot

=item Sys::Virt::DomainSnapshot::CREATE_DISK_ONLY

Only snapshot the disk, not the memory state

=item Sys::Virt::DomainSnapshot::CREATE_HALT

Stop the guest after creating the snapshot

=item Sys::Virt::DomainSnapshot::CREATE_NO_METADATA

Do not save any metadata for the snapshot

=item Sys::Virt::DomainSnapshot::CREATE_REDEFINE

Replace/set the metadata with the snapshot

=back

=head2 SNAPSHOT DELETION

The following constants are useful when deleting snapshots

=over 4

=item Sys::Virt::DomainSnapshot::DELETE_CHILDREN

Recursively delete any child snapshots

=item Sys::Virt::DomainSnapshot::DELETE_CHILDREN_ONLY

Only delete the child snapshots

=item Sys::Virt::DomainSnapshot::DELETE_METADATA_ONLY

Only delete the snapshot metadata

=back

=head2 SNAPSHOT LIST

The following constants are useful when listing snapshots

=over 4

=item Sys::Virt::DomainSnapshot::LIST_METADATA

Only list snapshots which have metadata

=item Sys::Virt::DomainSnapshot::LIST_ROOTS

Only list snapshots which are root nodes in the tree

=item Sys::Virt::DomainSnapshot::LIST_DESCENDANTS

Only list snapshots which are descendants of the current
snapshot

=item Sys::Virt::DomainSnapshot::LIST_LEAVES

Only list leave nodes in the snapshot tree

=back


=head2 SNAPSHOT REVERT

The following constants are useful when reverting snapshots

=over 4

=item Sys::Virt::DomainSnapshot::REVERT_PAUSED

Leave the guest CPUs paused after reverting to the snapshot state

=item Sys::Virt::DomainSnapshot::REVERT_RUNNING

Start the guest CPUs after reverting to the snapshot state

=item Sys::Virt::DomainSnapshot::REVERT_FORCE

Force the snapshot to revert, even if it is risky to do so

=back

=over 4

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
