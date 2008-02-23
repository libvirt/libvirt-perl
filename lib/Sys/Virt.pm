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

Sys::Virt - Represent and manage a libvirt hypervisor connection

=head1 SYNOPSIS

  my $vmm = Sys::Virt->new(address => $addr);

  my @domains = $vmm->list_domains();

  foreach my $dom (@domains) {
    print "Domain ", $dom->get_id, " ", $dom->get_name, "\n";
  }

=head1 DESCRIPTION

The Sys::Virt module provides a Perl XS binding to the libvirt
virtual machine management APIs. This allows machines running
within arbitrary virtualization containers to be managed with
a consistent API.

=head1 ERROR HANDLING

Any operations in the Sys::Virt API which have failure scenarios
will result in an instance of the L<Sys::Virt::Error> module being
thrown. To catch these errors, simply wrap the method in an eval
block. For details of the information contained in the error objects,
consult the L<Sys::Virt::Error> manual page.

=head1 METHODS

=over 4

=cut

package Sys::Virt;

use strict;
use warnings;

use Sys::Virt::Error;
use Sys::Virt::Domain;
use Sys::Virt::Network;

our $VERSION = '0.1.2';
require XSLoader;
XSLoader::load('Sys::Virt', $VERSION);

=item my $vmm = Sys::Virt->new(uri => $uri, readonly => $ro);

Attach to the virtual machine monitor with the address of C<address>. The
uri parameter may be omitted, in which case the default connection made
will be to the local Xen hypervisor. Some example URIs include:

=over 4

=item xen:///

Xen on the local machine

=item test:///default

Dummy "in memory" driver for test suites

=item qemu:///system

System-wide driver for QEMU / KVM virtualization

=item qemu:///session

Per-user driver for QEMU virtualization

=item qemu+tls://somehost/system

System-wide QEMU driver on C<somehost> using TLS security

=item xen+tcp://somehost/

Xen driver on C<somehost> using TCP / SASL security

=back

For further details consult C<http://libvirt.org/uri.html>

If the optional C<readonly> parameter is supplied, then an unprivileged
connection to the VMM will be attempted. If it is not supplied, then it
defaults to making a fully privileged connection to the VMM. If the
calling application is not running as root, it may be neccessary to
provide authentication callbacks.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $uri = exists $params{address} ? $params{address} : exists $params{uri} ? $params{uri} : "";
    my $readonly = exists $params{readonly} ? $params{readonly} : 0;
    my $self = Sys::Virt::_open($uri, $readonly);

    bless $self, $class;

    return $self;
}


=item my $dom = $vmm->create_domain($xml);

Create a new domain based on the XML description passed into the C<$xml>
parameter. The returned object is an instance of the L<Sys::Virt::Domain>
class. This method is not available with unprivileged connections to
the VMM.

=cut

sub create_domain {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::Domain->_new(connection => $self, xml => $xml);
}

=item my $dom = $vmm->define_domain($xml);

Defines, but does not start, a new domain based on the XML description
passed into the C<$xml> parameter. The returned object is an instance
of the L<Sys::Virt::Domain> class. This method is not available with
unprivileged connections to the VMM. The define can be later started
by calling the C<create> method on the returned C<Sys::Virt::Domain>
object.

=cut

sub define_domain {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::Domain->_new(connection => $self, xml => $xml, nocreate => 1);
}

=item my $dom = $vmm->create_network($xml);

Create a new network based on the XML description passed into the C<$xml>
parameter. The returned object is an instance of the L<Sys::Virt::Network>
class. This method is not available with unprivileged connections to
the VMM.

=cut

sub create_network {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::Network->_new(connection => $self, xml => $xml);
}

=item my $dom = $vmm->define_network($xml);

Defines, but does not start, a new network based on the XML description
passed into the C<$xml> parameter. The returned object is an instance
of the L<Sys::Virt::Network> class. This method is not available with
unprivileged connections to the VMM. The define can be later started
by calling the C<create> method on the returned C<Sys::Virt::Network>
object.

=cut

sub define_network {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::Network->_new(connection => $self, xml => $xml, nocreate => 1);
}

=item my @doms = $vmm->list_domains()

Return a list of all domains currently known to the VMM. The elements
in the returned list are instances of the L<Sys::Virt::Domain> class.

=cut

sub list_domains {
    my $self = shift;

    my $nids = $self->num_of_domains();
    my @ids = $self->list_domain_ids($nids);

    my @domains;
    foreach my $id (@ids) {
	eval {
	    push @domains, Sys::Virt::Domain->_new(connection => $self, id => $id);
	};
	if ($@) {
	    # nada - domain went away before we could look it up
	};
    }
    return @domains;
}

=item my $nids = $vmm->num_of_domains()

Return the number of running domains known to the VMM. This can be
used as the C<maxids> parameter to C<list_domain_ids>.

=item my @domIDs = $vmm->list_domain_ids($maxids)

Return a list of all domain IDs currently known to the VMM. The IDs can
be used with the C<get_domain_by_id> method.

=item my @doms = $vmm->list_defined_domains()

Return a list of all domains defined, but not currently running, on the
VMM. The elements in the returned list are instances of the
L<Sys::Virt::Domain> class.

=cut

sub list_defined_domains {
    my $self = shift;

    my $nnames = $self->num_of_defined_domains();
    my @names = $self->list_defined_domain_names($nnames);

    my @domains;
    foreach my $name (@names) {
	eval {
	    push @domains, Sys::Virt::Domain->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - domain went away before we could look it up
	};
    }
    return @domains;
}

=item my $nids = $vmm->num_of_defined_domains()

Return the number of running domains known to the VMM. This can be
used as the C<maxnames> parameter to C<list_defined_domain_names>.

=item my @doms = $vmm->list_defined_domain_names($maxnames)

Return a list of names of all domains defined, but not currently running, on
the VMM. The names can be used with the C<get_domain_by_name> method.

=item my $dom = $vmm->get_domain_by_name($name)

Return the domain with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::Domain> class.

=item my @nets = $vmm->list_networks()

Return a list of all networks currently known to the VMM. The elements
in the returned list are instances of the L<Sys::Virt::Network> class.

=cut

sub list_networks {
    my $self = shift;

    my $nnames = $self->num_of_networks();
    my @names = $self->list_network_names($nnames);

    my @networks;
    foreach my $name (@names) {
	eval {
	    push @networks, Sys::Virt::Network->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - network went away before we could look it up
	};
    }
    return @networks;
}

=item my $nnames = $vmm->num_of_networks()

Return the number of running networks known to the VMM. This can be
used as the C<maxids> parameter to C<list_network_ids>.

=item my @netNames = $vmm->list_network_names($maxnames)

Return a list of all network IDs currently known to the VMM. The IDs can
be used with the C<get_network_by_id> method.

=item my @nets = $vmm->list_defined_networks()

Return a list of all networks defined, but not currently running, on the
VMM. The elements in the returned list are instances of the
L<Sys::Virt::Network> class.

=cut

sub list_defined_networks {
    my $self = shift;

    my $nnames = $self->num_of_defined_networks();
    my @names = $self->list_defined_network_names($nnames);

    my @networks;
    foreach my $name (@names) {
	eval {
	    push @networks, Sys::Virt::Network->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - network went away before we could look it up
	};
    }
    return @networks;
}

=item my $nids = $vmm->num_of_defined_networks()

Return the number of running networks known to the VMM. This can be
used as the C<maxnames> parameter to C<list_defined_network_names>.

=item my @doms = $vmm->list_defined_network_names($maxnames)

Return a list of names of all networks defined, but not currently running, on
the VMM. The names can be used with the C<get_network_by_name> method.

=item my $dom = $vmm->get_domain_by_name($name)

Return the domain with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::Domain> class.

=cut

sub get_domain_by_name {
    my $self = shift;
    my $name = shift;

    return Sys::Virt::Domain->_new(connection => $self, name => $name);
}



=item my $dom = $vmm->get_domain_by_id($id)

Return the domain with a local id of C<$id>. The returned object is
an instance of the L<Sys::Virt::Domain> class.

=cut

sub get_domain_by_id {
    my $self = shift;
    my $id = shift;

    return Sys::Virt::Domain->_new(connection => $self, id => $id);
}



=item my $dom = $vmm->get_domain_by_uuid($uuid)

Return the domain with a globally unique id of C<$uuid>. The returned object is
an instance of the L<Sys::Virt::Domain> class.

=cut

sub get_domain_by_uuid {
    my $self = shift;
    my $uuid = shift;

    return Sys::Virt::Domain->_new(connection => $self, uuid => $uuid);
}

=item my $dom = $vmm->get_network_by_name($name)

Return the network with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::Network> class.

=cut

sub get_network_by_name {
    my $self = shift;
    my $name = shift;

    return Sys::Virt::Network->_new(connection => $self, name => $name);
}


=item my $dom = $vmm->get_network_by_uuid($uuid)

Return the network with a globally unique id of C<$uuid>. The returned object is
an instance of the L<Sys::Virt::Network> class.

=cut

sub get_network_by_uuid {
    my $self = shift;
    my $uuid = shift;

    return Sys::Virt::Network->_new(connection => $self, uuid => $uuid);
}

=item $vmm->restore_domain($savefile)

Recreate a domain from the saved state file given in the C<$savefile> parameter.

=item $vmm->get_max_vcpus($domtype)

Return the maximum number of vcpus that can be configured for a domain
of type C<$domtype>

=item $vmm->get_hostname()

Return the name of the host with which this connection is associated.

=item my $type = $vmm->get_type()

Return the type of virtualization backend accessed by this VMM object. Currently
the only supported type is C<Xen>.

=item my $ver = $vmm->get_version()

Return the complete version number as a string encoded in the
formula C<(major * 1000000) + (minor * 1000) + micro>.

=item my $ver = $vmm->get_major_version

Return the major version number of the libvirt library.

=cut

sub get_major_version {
    my $self = shift;
    my $ver = $self->get_version;
    return ($ver - ($ver % 1000000))/1000000;
}


=item my $ver = $vmm->get_minor_version

Return the minor version number of the libvirt library.

=cut

sub get_minor_version {
    my $self = shift;
    my $ver = $self->get_version;
    my $mver = $ver % 1000000;
    return ($mver - ($mver % 1000)) / 1000;
}

=item my $ver = $vmm->get_micro_version

Return the micro version number of the libvirt library.

=cut

sub get_micro_version {
    my $self = shift;
    return $self->get_version % 1000;
}

1;

=pod

=item my $info = $con->get_node_info()

Returns a hash reference summarising the capabilities of the host
node. The elements of the hash are as follows:

=over 4

=item memory

The amount of physical memory in the host

=item model

The model of the CPU, eg x86_64

=item cpus

The total number of logical CPUs

=item mhz

The peak MHZ of the CPU

=item nodes

The number of NUMA cells

=item sockets

The number of CPU sockets

=item cores

The number of cores per socket

=item threads

The number of threads per core

=back

=item my $xml = $con->get_capabilities();

Returns an XML document describing the hypervisor capabilities

=back

=head1 BUGS

Hopefully none, but the XS code needs to be audited to ensure it
is not leaking memory.

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

L<Sys::Virt::Domain>, L<Sys::Virt::Network>, L<Sys::Virt::Error>, C<http://libvirt.org>

=cut
