=pod

=head1 NAME

Sys::Virt - interface to libvirt virtual machine management API

=head1 DESCRIPTION

The C<Sys::Virt::Domain> module represents a guest domain managed
by the virtual machine monitor.

=head1 METHODS

=over 4

=cut

package Sys::Virt::Domain;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    
    my $con = exists $params{connection} ? $params{connection} : die "connection parameter is requried";
    my $self;
    if (exists $params{address}) {
	$self = Sys::Virt::Domain::_lookup_by_name($con,  $params{address});
    } elsif (exists $params{id}) {
	$self = Sys::Virt::Domain::_lookup_by_id($con,  $params{id});
    } elsif (exists $params{uuid}) {
	$self = Sys::Virt::Domain::_lookup_by_uuid($con,  $params{uuid});
    } elsif (exists $params{xml}) {
	$self = Sys::Virt::Domain::_create_linux($con,  $params{xml});
    } else {
	die "address, id or uuid parameters are required";
    }

    bless $self, $class;
    
    return $self;
}


=item my $id = $dom->get_id()

Returns an integer with a locally unique identifier for the
domain.

=item my $uuid = $dom->get_uuid()

Returns a string containing a globally unique identifier for
the domain.

=item my $name = $dom->get_name()

Returns a string with a locally unique name of the domain

=item my $xml = $dom->get_xml_description()

Returns an XML document containing a complete description of
the domain's configuration

=item my $type = $dom->get_os_type()

Returns a string containing the name of the OS type running
within the domain.

=item $dom->suspend

Temporarily stop execution of the domain, allowing later continuation
by calling the C<resume> method.

=item $dom->resume

Resume execution of a domain previously halted with the C<suspend>
method.

=item $dom->save($filename)

Take a snapshot of the domain's state and save the information to
the file named in the C<$filename> parameter. The domain can later
be restored from this file with the C<restore_domain> method on
the L<Sys::Virt> object.

=item $dom->destroy()

Immediately terminate the machine, and remove it from the virtual
machine monitor. The C<$dom> handle is invalid after this call
completes and should not be used again.

=item my $info = $dom->get_info()

Returns a hash reference summarising the execution state of the
domain. The elements of the hash ar

=over 4

=item maxMem

The maximum memory allowed for this domain, in kilobytes

=item memory

The current memory allocated to the domain in kilobytes

=item nrVirtCpus

The current number of virtual CPUs enabled in the domain

=item state

The execution state of the machine, one of the strings
C<running>, C<blocked>, C<paused>, C<shutdown>, C<shutoff>,
C<crashed> or C<unknown>.

=back

=item $dom->set_max_memory($mem)

Set the maximum memory for the domain to the value C<$mem>. The
value of the C<$mem> parameter is specified in kilobytes

=item $mem = $dom->get_max_memory()

Returns the current maximum memory allowed for this domain in
kilobytes.

=item $dom->shutdown()

Request that the guest OS perform a gracefull shutdown and
poweroff.

=cut

1;

=back

=head1 AUTHORS

Daniel P. Berrange <berrange@redhat.com>

=head1 COPYRIGHT / LICENSE

Copyright (C) 2006 Red Hat

Sys::Virt is distributed under the terms of the GPLv2 or later

=head1 SEE ALSO

L<Sys::Virt>, L<Sys::Virt::Error>, C<http://libvirt.org>

=cut
