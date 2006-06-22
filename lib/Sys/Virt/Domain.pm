=pod

=head1 NAME

Sys::Virt::Domain - Represent & manage a libvirt guest domain

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
    if (exists $params{name}) {
	$self = Sys::Virt::Domain::_lookup_by_name($con,  $params{name});
    } elsif (exists $params{id}) {
	$self = Sys::Virt::Domain::_lookup_by_id($con,  $params{id});
    } elsif (exists $params{uuid}) {
	if (len($params{uuid} == 16)) {
	    $self = Sys::Virt::Domain::_lookup_by_uuid($con,  $params{uuid});
	} elsif (len($params{uuid} == 32) ||
		 len($params{uuid} == 36)) {
	    $self = Sys::Virt::Domain::_lookup_by_uuid_striing($con,  $params{uuid});
	} else {
	    die "UUID must be either 16 unsigned bytes, or 32/36 hex characters long";
	}
    } elsif (exists $params{xml}) {
	if ($params{nocreate}) {
	    $self = Sys::Virt::Domain::_define_xml($con,  $params{xml});
	} else {
	    $self = Sys::Virt::Domain::_create_linux($con,  $params{xml});
	}
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

Returns a 16 byte long string containing the raw globally unique identifier
(UUID) for the domain.

=item my $uuid = $dom->get_uuid_string()

Returns a printable string representation of the raw UUID, in the format
'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'.

=item my $name = $dom->get_name()

Returns a string with a locally unique name of the domain

=item my $xml = $dom->get_xml_description()

Returns an XML document containing a complete description of
the domain's configuration

=item my $type = $dom->get_os_type()

Returns a string containing the name of the OS type running
within the domain.

=item $dom->create()

Start a domain whose configuration was previously defined using the
C<define_domain> method in L<Sys::Virt>.

=item $dom->undefine()

Remove the configuration associated with a domain previously defined
with the C<define_domain> method in L<Sys::Virt>. If the domain is
running, you probably want to use the C<shutdown> or C<destroy>
methods instead.

=item $dom->suspend()

Temporarily stop execution of the domain, allowing later continuation
by calling the C<resume> method.

=item $dom->resume()

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

The execution state of the machine, which will be one of the
constants &Sys::Virt::Domain::STATE_*.

=back

=item $dom->set_max_memory($mem)

Set the maximum memory for the domain to the value C<$mem>. The
value of the C<$mem> parameter is specified in kilobytes

=item $mem = $dom->get_max_memory()

Returns the current maximum memory allowed for this domain in
kilobytes.

=item $dom->set_memory($mem)

Set the current memory for the domain to the value C<$mem>. The
value of the C<$mem> parameter is specified in kilobytes. This
must be less than, or equal to the domain's max memory limit.

=item $dom->shutdown()

Request that the guest OS perform a gracefull shutdown and
poweroff.

=item $dom->reboot($flags)

Request that the guest OS perform a gracefull shutdown and
optionally restart. The C<$flags> parameter determines how
the domain restarts (if at all). It should be one of the
constants &Sys::Virt::Domain::REBOOT_* listed later in this
document.

=cut


sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    die "&Sys::Virt::Domain::constant not defined" if $constname eq '_constant';
    if (!exists $Sys::Virt::Domain::_constants{$constname}) {
	die "no such constant \$" . __PACKAGE__ . "::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Sys::Virt::Domain::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}


1;

=back

=head1 CONSTANTS

The first set of constants enumerate the possible machine
runtime states, returned by the C<get_info> method.

=over 4

=item &Sys::Virt::Domain::STATE_NOSTATE

The domain is active, but is not running / blocked (eg idle)

=item &Sys::Virt::Domain::STATE_RUNNING

The domain is active and running

=item &Sys::Virt::Domain::STATE_BLOCKED

The domain is active, but execution is blocked

=item &Sys::Virt::Domain::STATE_PAUSED

The domain is active, but execution has been paused

=item &Sys::Virt::Domain::STATE_SHUTDOWN

The domain is active, but in the shutdown phase

=item &Sys::Virt::Domain::STATE_SHUTOFF

The domain is inactive, and shut down.

=item &Sys::Virt::Domain::STATE_CRASHED

The domain is inactive, and crashed.

=back

The next set of constants enumerate the different flags
which can be passed when requesting a reboot.

=over 4

=item &Sys::Virt::Domain::REBOOT_DESTROY

Destroy the domain, rather than restarting the domain

=item &Sys::Virt::Domain::REBOOT_RESTART

Restart the domain after shutdown is complete

=item &Sys::Virt::Domain::REBOOT_PRESERVE

Leave the domain inactive after shutdown is complete

=item &Sys::Virt::Domain::REBOOT_RENAME_RESTART

Restart the domain under a different (automatically generated) name
after shutdown is complete

=back

=head1 AUTHORS

Daniel P. Berrange <berrange@redhat.com>

=head1 COPYRIGHT / LICENSE

Copyright (C) 2006 Red Hat

Sys::Virt is distributed under the terms of the GPLv2 or later

=head1 SEE ALSO

L<Sys::Virt>, L<Sys::Virt::Error>, C<http://libvirt.org>

=cut
