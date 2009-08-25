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
use Sys::Virt::StoragePool;
use Sys::Virt::StorageVol;
use Sys::Virt::NodeDevice;

our $VERSION = '0.2.1';
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

If the optional C<auth> parameter is set to a non-zero value,
authentication will be enabled during connection, using the
default set of credential gathering callbacks. The default
callbacks prompt for credentials on the console, so are not
suitable for graphical applications. For such apps a custom
implementation should be supplied. The C<credlist> parameter
should be an array reference listing the set of credential
types that will be supported. The credential constants in
this module can be used as values in this list. The C<callback>
parameter should be a subroutine reference containing the
code neccessary to gather the credentials. When invoked it
will be supplied with a single parameter, a array reference
of requested credentials. The elements of the array are
hash references, with keys C<type> giving the type of
credential, C<prompt> giving a user descriptive user
prompt, C<challenge> giving name of the credential
required. The answer should be collected from the user, and
returned by setting the C<result> key. This key may already
be set with a default result if applicable

As a simple example returning hardcoded credentials

    my $address  = "qemu+tcp://192.168.122.1/system";
    my $username = "test";
    my $password = "123456";

    my $con = Sys::Virt->new(address => $address,
                             auth => 1,
                             credlist => [
                               Sys::Virt::CRED_AUTHNAME,
                               Sys::Virt::CRED_PASSPHRASE,
                             ],
                             callback =>
         sub {
               my $creds = shift;

               foreach my $cred (@{$creds}) {
                  if ($cred->{type} == Sys::Virt::CRED_AUTHNAME) {
                      $cred->{result} = $username;
                  }
                  if ($cred->{type} == Sys::Virt::CRED_PASSPHRASE) {
                      $cred->{result} = $password;
                  }
               }
               return 0;
         });

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $uri = exists $params{address} ? $params{address} : exists $params{uri} ? $params{uri} : undef;
    my $readonly = exists $params{readonly} ? $params{readonly} : 0;
    my $auth = exists $params{auth} ? $params{auth} : 0;

    my $authcb = exists $params{callback} ? $params{callback} : undef;
    my $credlist = exists $params{credlist} ? $params{credlist} : undef;

    my $self;

    if ($auth) {
	$self = Sys::Virt::_open_auth($uri, $readonly, $credlist, $authcb);
    } else {
	$self = Sys::Virt::_open($uri, $readonly);
    }

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
unprivileged connections to the VMM. The defined domain can be later started
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
unprivileged connections to the VMM. The defined network can be later started
by calling the C<create> method on the returned C<Sys::Virt::Network>
object.

=cut

sub define_network {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::Network->_new(connection => $self, xml => $xml, nocreate => 1);
}

=item my $dom = $vmm->create_storage_pool($xml);

Create a new storage pool based on the XML description passed into the C<$xml>
parameter. The returned object is an instance of the L<Sys::Virt::StoragePool>
class. This method is not available with unprivileged connections to
the VMM.

=cut

sub create_storage_pool {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::StoragePool->_new(connection => $self, xml => $xml);
}

=item my $dom = $vmm->define_storage_pool($xml);

Defines, but does not start, a new storage pol based on the XML description
passed into the C<$xml> parameter. The returned object is an instance
of the L<Sys::Virt::StoragePool> class. This method is not available with
unprivileged connections to the VMM. The defined pool can be later started
by calling the C<create> method on the returned C<Sys::Virt::StoragePool>
object.

=cut

sub define_storage_pool {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::StoragePool->_new(connection => $self, xml => $xml, nocreate => 1);
}

=item my $dom = $vmm->create_node_device($xml);

Create a new virtual node device based on the XML description passed into the
C<$xml> parameter. The returned object is an instance of the L<Sys::Virt::NodeDevice>
class. This method is not available with unprivileged connections to
the VMM.

=cut

sub create_node_device {
    my $self = shift;
    my $xml = shift;

    return Sys::Virt::NodeDevice->_new(connection => $self, xml => $xml);
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

=item my $nnames = $vmm->num_of_defined_domains()

Return the number of running domains known to the VMM. This can be
used as the C<maxnames> parameter to C<list_defined_domain_names>.

=item my @names = $vmm->list_defined_domain_names($maxnames)

Return a list of names of all domains defined, but not currently running, on
the VMM. The names can be used with the C<get_domain_by_name> method.

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

Return a list of all network names currently known to the VMM. The names can
be used with the C<get_network_by_name> method.

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

=item my $nnamess = $vmm->num_of_defined_networks()

Return the number of running networks known to the host. This can be
used as the C<maxnames> parameter to C<list_defined_network_names>.

=item my @names = $vmm->list_defined_network_names($maxnames)

Return a list of names of all networks defined, but not currently running, on
the host. The names can be used with the C<get_network_by_name> method.

=item my @pools = $vmm->list_storage_pools()

Return a list of all storage pools currently known to the host. The elements
in the returned list are instances of the L<Sys::Virt::StoragePool> class.

=cut

sub list_storage_pools {
    my $self = shift;

    my $nnames = $self->num_of_storage_pools();
    my @names = $self->list_storage_pool_names($nnames);

    my @pools;
    foreach my $name (@names) {
	eval {
	    push @pools, Sys::Virt::StoragePool->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - storage pool went away before we could look it up
	};
    }
    return @pools;
}

=item my $nnames = $vmm->num_of_storage_pools()

Return the number of running storage pools known to the VMM. This can be
used as the C<maxids> parameter to C<list_storage_pool_names>.

=item my @poolNames = $vmm->list_storage_pool_names($maxnames)

Return a list of all storage pool names currently known to the VMM. The IDs can
be used with the C<get_network_by_id> method.

=item my @pools = $vmm->list_defined_storage_pools()

Return a list of all storage pools defined, but not currently running, on the
host. The elements in the returned list are instances of the
L<Sys::Virt::StoragePool> class.

=cut

sub list_defined_storage_pools {
    my $self = shift;

    my $nnames = $self->num_of_defined_storage_pools();
    my @names = $self->list_defined_storage_pool_names($nnames);

    my @pools;
    foreach my $name (@names) {
	eval {
	    push @pools, Sys::Virt::StoragePool->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - storage pool went away before we could look it up
	};
    }
    return @pools;
}

=item my $nnames = $vmm->num_of_defined_storage_pools()

Return the number of running networks known to the host. This can be
used as the C<maxnames> parameter to C<list_defined_storage_pool_names>.

=item my @names = $vmm->list_defined_storage_pool_names($maxnames)

Return a list of names of all storage pools defined, but not currently running, on
the host. The names can be used with the C<get_storage_pool_by_name> method.

=item my @devs = $vmm->list_node_devices($capability)

Return a list of all devices currently known to the host OS. The elements
in the returned list are instances of the L<Sys::Virt::NodeDevice> class.
The optional C<capability> parameter allows the list to be restricted to
only devices with a particular capability type.

=cut

sub list_node_devices {
    my $self = shift;
    my $cap = shift;

    my $nnames = $self->num_of_node_devices($cap);
    my @names = $self->list_node_device_names($cap, $nnames);

    my @devs;
    foreach my $name (@names) {
	eval {
	    push @devs, Sys::Virt::NodeDevice->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - device went away before we could look it up
	};
    }
    return @devs;
}

=item my $nnames = $vmm->num_of_node_devices($capability)

Return the number of host devices known to the VMM. This can be
used as the C<maxids> parameter to C<list_node_device_names>.
The optional C<capability> parameter allows the list to be restricted to
only devices with a particular capability type.

=item my @netNames = $vmm->list_node_device_names($capability, $maxnames)

Return a list of all host device names currently known to the VMM. The names can
be used with the C<get_node_device_by_name> method.
The optional C<capability> parameter allows the list to be restricted to
only devices with a particular capability type.

=item my @ifaces = $vmm->list_interfaces()

Return a list of all network interfaces currently known to the VMM. The elements
in the returned list are instances of the L<Sys::Virt::Interface> class.

=cut

sub list_interfaces {
    my $self = shift;

    my $nnames = $self->num_of_interfaces();
    my @names = $self->list_interface_names($nnames);

    my @interfaces;
    foreach my $name (@names) {
	eval {
	    push @interfaces, Sys::Virt::Interface->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - interface went away before we could look it up
	};
    }
    return @interfaces;
}

=item my $nnames = $vmm->num_of_interfaces()

Return the number of running interfaces known to the VMM. This can be
used as the C<maxnames> parameter to C<list_interface_names>.

=item my @names = $vmm->list_interface_names($maxnames)

Return a list of all interface names currently known to the VMM. The names can
be used with the C<get_interface_by_name> method.

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

=item my $net = $vmm->get_network_by_name($name)

Return the network with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::Network> class.

=cut

sub get_network_by_name {
    my $self = shift;
    my $name = shift;

    return Sys::Virt::Network->_new(connection => $self, name => $name);
}


=item my $net = $vmm->get_network_by_uuid($uuid)

Return the network with a globally unique id of C<$uuid>. The returned object is
an instance of the L<Sys::Virt::Network> class.

=cut

sub get_network_by_uuid {
    my $self = shift;
    my $uuid = shift;

    return Sys::Virt::Network->_new(connection => $self, uuid => $uuid);
}

=item my $pool = $vmm->get_storage_pool_by_name($name)

Return the storage pool with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::StoragePool> class.

=cut

sub get_storage_pool_by_name {
    my $self = shift;
    my $name = shift;

    return Sys::Virt::StoragePool->_new(connection => $self, name => $name);
}


=item my $pool = $vmm->get_storage_pool_by_uuid($uuid)

Return the storage pool with a globally unique id of C<$uuid>. The returned object is
an instance of the L<Sys::Virt::StoragePool> class.

=cut

sub get_storage_pool_by_uuid {
    my $self = shift;
    my $uuid = shift;

    return Sys::Virt::StoragePool->_new(connection => $self, uuid => $uuid);
}

=item my $dev = $vmm->get_node_device_by_name($name)

Return the node device with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::NodeDevice> class.

=cut

sub get_node_device_by_name {
    my $self = shift;
    my $name = shift;

    return Sys::Virt::NodeDevice->_new(connection => $self, name => $name);
}


=item my $iface = $vmm->get_interface_by_name($name)

Return the interface with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::Interface> class.

=cut

sub get_interface_by_name {
    my $self = shift;
    my $name = shift;

    return Sys::Virt::Interface->_new(connection => $self, name => $name);
}


=item my $iface = $vmm->get_interface_by_mac($mac)

Return the interface with a MAC address of C<$mac>. The returned object is
an instance of the L<Sys::Virt::Interface> class.

=cut

sub get_interface_by_mac {
    my $self = shift;
    my $mac = shift;

    return Sys::Virt::Interface->_new(connection => $self, mac => $mac);
}


=item my $xml = $vmm->find_storage_pool_sources($type, $srcspec, $flags)

Probe for available storage pool sources for the pool of type C<$type>.
The C<$srcspec> parameter can be C<undef>, or a parameter to refine the
discovery process, for example a server hostname for NFS discovery. The
C<$flags> parameter can usually be left as zero. The return scalar is
an XML document describing the discovered storage pool sources.

=item $vmm->restore_domain($savefile)

Recreate a domain from the saved state file given in the C<$savefile> parameter.

=item $vmm->get_max_vcpus($domtype)

Return the maximum number of vcpus that can be configured for a domain
of type C<$domtype>

=item my $hostname = $vmm->get_hostname()

Return the name of the host with which this connection is associated.

=item my $uri = $vmm->get_uri()

Return the URI associated with the open connection. This may be different
from the URI used when initially connecting to libvirt, when 'auto-probing'
or drivers occurrs.

=item my $type = $vmm->get_type()

Return the type of virtualization backend accessed by this VMM object. Currently
the only supported type is C<Xen>.

=item my $xml = $vmm->domain_xml_from_native($format, $config);

Convert the native hypervisor configuration C<$config> which is in format
<$format> into libvirrt domain XML. Valid values of C<$format> vary between
hypervisor drivers.

=item my $config = $vmm->domain_xml_to_native($format, $xml)

Convert the libvirt domain XML configuration C<$xml> to a native hypervisor
configuration in format C<$format>

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

sub get_version {
    my $self = shift;
    if (defined $self) {
	return $self->_get_conn_version;
    } else {
	return &Sys::Virt::_get_library_version();
    }
}

1;

=pod

=item my $info = $con->get_node_info()

Returns a hash reference summarising the capabilities of the host
node. The elements of the hash are as follows:

=item $conn->domain_event_register($callback)

Register a callback to received notificaitons of domain state change
events. Only a single callback can be registered with each connection
instance. The callback will be invoked with four paramters, an
instance of C<Sys::Virt> for the connection, an instance of C<Sys::Virt::Domain>
for the domain changing state, and a C<event> and C<detail> arguments,
corresponding to the event constants defined in the C<Sys::Virt::Domain>
module. Before discarding the connection object, the callback must be
deregistered, otherwise the connection object memory will never be
released in garbage collection.

=item $conn->domain_event_deregister()

Unregister a callback, allowing the connection object to be garbage
collected.

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

=item my $info = $con->get_node_security_model()

Returns a hash reference summarising the security model of the
host node. There are two keys in the hash, C<model> specifying
the name of the security model (eg 'selinux') and C<doi>
specifying the 'domain of interpretation' for security labels.

=item my $xml = $con->get_capabilities();

Returns an XML document describing the hypervisor capabilities

=item $mem = $con->get_node_free_memory();

Returns the current free memory on the host

=item @mem = $con->get_node_cells_free_memory($start, $end);

Returns the free memory on each NUMA cell between C<$start> and C<$end>.

=back

=head1 CONSTANTS

The following sets of constants are useful when dealing with APIs
in this package

=head2 CREDENTIAL TYPES

When providing authentication callbacks, the following constants
indicate the type of credential being requested

=over 4

=item Sys::Virt::CRED_AUTHNAME

Identity to act as

=item Sys::Virt::CRED_USERNAME

Identity to authorize as

=item Sys::Virt::CRED_CNONCE

Client supplies a nonce

=item Sys::Virt::CRED_REALM

Authentication realm

=item Sys::Virt::CRED_ECHOPROMPT

Challenge response non-secret

=item Sys::Virt::CRED_NOECHOPROMPT

Challenge response secret

=item Sys::Virt::CRED_PASSPHRASE

Passphrase secret

=item Sys::Virt::CRED_LANGUAGE

RFC 1766 language code

=item Sys::Virt::CRED_EXTERNAL

Externally provided credential

=back

=head1 BUGS

Hopefully none, but the XS code needs to be audited to ensure it
is not leaking memory.

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

L<Sys::Virt::Domain>, L<Sys::Virt::Network>, L<Sys::Virt::StoragePool>,
L<Sys::Virt::StorageVol>, L<Sys::Virt::Error>, C<http://libvirt.org>

=cut
