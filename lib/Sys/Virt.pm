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

our $VERSION = '0.1.1';
require XSLoader;
XSLoader::load('Sys::Virt', $VERSION);

=item my $vmm = Sys::Virt->new(address => $address, readonly => $ro);

Attach to the virtual machine monitor with the address of C<address>. The
address parameter may be omitted, in which case the default connection made
will be to the local Xen hypervisor. In the future it wil be possible to
specify explicit addresses for other types of hypervisor connection.
If the optional C<readonly> parameter is supplied, then an unprivileged
connection to the VMM will be attempted. If it is not supplied, then it
defaults to making a fully privileged connection to the VMM. THis in turn
requires that the calling application be running as root.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $address = exists $params{address} ? $params{address} : "";
    my $readonly = exists $params{readonly} ? $params{readonly} : 0;
    my $self = Sys::Virt::_open($address, $readonly);

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

=item my @doms = $vmm->list_domains()

Return a list of all domains currently known to the VMM. The elements
in the returned list are instances of the L<Sys::Virt::Domain> class.

=cut

sub list_domains {
    my $self = shift;

    my $ids = $self->_list_domain_ids();

    my @domains;
    foreach my $id (@{$ids}) {
	push @domains, Sys::Virt::Domain->_new(connection => $self, id => $id);
    }
    return @domains;
}

#=item my @doms = $vmm->list_defined_domains()
#
#Return a list of all domains defined, but not currently running, on the
#VMM. The elements in the returned list are instances of the
#L<Sys::Virt::Domain> class.
#
#=cut
#
#sub list_defined_domains {
#    my $self = shift;
#
#    my $names = $self->_list_defined_domains();
#
#    my @domains;
#    foreach my $name (@{$names}) {
#	push @domains, Sys::Virt::Domain->_new(connection => $self, name => $name);
#    }
#    return @domains;
#}

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

=item $vmm->restore_domain($savefile)

Recreate a domain from the saved state file given in the C<$savefile> parameter.

=cut

=item my $type = $vmm->get_type()

Return the type of virtualization backend accessed by this VMM object. Curently
the only supported type is C<Xen>.

=cut

=item my $ver = $vmm->get_version()

Return the complete version number as a string encoded in the
formula C<(major * 1000000) + (minor * 1000) + micro>.

=cut


=item my $ver = $vmm->get_major_version

Return the major version number of the libvirt library

=cut

sub get_major_version {
    my $self = shift;
    my $ver = $self->get_version;
    return ($ver - ($ver % 1000000))/1000000;
}


=item my $ver = $vmm->get_minor_version

Return the minor version number of the libvirt library

=cut

sub get_minor_version {
    my $self = shift;
    my $ver = $self->get_version;
    my $mver = $ver % 1000000;
    return ($mver - ($mver % 1000)) / 1000;
}

=item my $ver = $vmm->get_micro_version

Return the micro version number of the libvirt library

=cut

sub get_micro_version {
    my $self = shift;
    return $self->get_version % 1000;
}

1;

=pod

=item my $info = $con->get_node_info()

Returns a hash reference summarising the capabilities of the host
node. The elements of the hash ar

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

=back

=head1 BUGS

Hopefully none, but the XS code needs to be audited to ensure it
is not leaking memory

=head1 AUTHORS

Daniel P. Berrange <berrange@redhat.com>

=head1 COPYRIGHT / LICENSE

Copyright (C) 2006 Red Hat

Sys::Virt is distributed under the terms of the GPLv2 or later

=head1 SEE ALSO

L<Sys::Virt::Domain>, L<Sys::Virt::Error>, C<http://libvirt.org>

=cut
