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
	if (length($params{uuid}) == 16) {
	    $self = Sys::Virt::Domain::_lookup_by_uuid($con,  $params{uuid});
	} elsif (length($params{uuid}) == 32 ||
		 length($params{uuid}) == 36) {
	    $self = Sys::Virt::Domain::_lookup_by_uuid_string($con,  $params{uuid});
	} else {
	    die "UUID must be either 16 unsigned bytes, or 32/36 hex characters long";
	}
    } elsif (exists $params{xml}) {
	if ($params{nocreate}) {
	    $self = Sys::Virt::Domain::_define_xml($con,  $params{xml});
	} else {
	    $self = Sys::Virt::Domain::_create($con,  $params{xml}, $params{flags});
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

=item $dom->is_active()

Returns a true value if the domain is currently running

=item $dom->is_persistent()

Returns a true value if the domain has a persistent configuration
file defined

=item $dom->is_updated()

Returns a true value if the domain is running and has a persistent
configuration file defined that is out of date compared to the
current live config.

=item my $xml = $dom->get_xml_description()

Returns an XML document containing a complete description of
the domain's configuration

=item my $type = $dom->get_os_type()

Returns a string containing the name of the OS type running
within the domain.

=item $dom->create($flags)

Start a domain whose configuration was previously defined using the
C<define_domain> method in L<Sys::Virt>. The C<$flags> parameter
accepts one of the DOMAIN CREATION constants documented later, and
defaults to 0 if omitted.

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

=item $dom->managed_save($flags=0)

Take a snapshot of the domain's state and save the information to
a managed save location. The domain will be automatically restored
with this state when it is next started. The C<$flags> parameter is
unused and defaults to zero.

=item $bool = $dom->has_managed_save_image($flags=0)

Return a non-zero value if the domain has a managed save image
that will be used at next start. The C<$flags> parameter is
unused and defaults to zero.

=item $dom->managed_save_remove($flags=0)

Remove the current managed save image, causing the guest to perform
a full boot next time it is started. The C<$flags> parameter is
unused and defaults to zero.

=item $dom->core_dump($filename[, $flags])

Trigger a core dump of the guest virtual machine, saving its memory
image to C<$filename> so it can be analysed by tools such as C<crash>.
The optional C<$flags> flags parameter is currently unused and if
omitted will default to 0.

=item $dom->destroy()

Immediately terminate the machine, and remove it from the virtual
machine monitor. The C<$dom> handle is invalid after this call
completes and should not be used again.

=item my $info = $dom->get_info()

Returns a hash reference summarising the execution state of the
domain. The elements of the hash are as follows:

=over 4

=item maxMem

The maximum memory allowed for this domain, in kilobytes

=item memory

The current memory allocated to the domain in kilobytes

=item cpuTime

The amount of CPU time used by the domain

=item nrVirtCpu

The current number of virtual CPUs enabled in the domain

=item state

The execution state of the machine, which will be one of the
constants &Sys::Virt::Domain::STATE_*.

=back

=item my $info = $dom->get_block_info($dev, $flags=0)

Returns a hash reference summarising the disk usage of
the host backing store for a guest block device. The
C<$dev> parameter should be the path to the backing
store on the host. C<$flags> is currently unused and
defaults to 0 if omitted. The returned hash contains
the following elements

=over 4

=item capacity

Logical size in bytes of the block device backing image *

=item allocation

Highest allocated extent in bytes of the block device backing image

=item physical

Physical size in bytes of the container of the backing image

=back

=item $dom->set_max_memory($mem)

Set the maximum memory for the domain to the value C<$mem>. The
value of the C<$mem> parameter is specified in kilobytes.

=item $mem = $dom->get_max_memory()

Returns the current maximum memory allowed for this domain in
kilobytes.

=item $dom->set_memory($mem)

Set the current memory for the domain to the value C<$mem>. The
value of the C<$mem> parameter is specified in kilobytes. This
must be less than, or equal to the domain's max memory limit.

=item $dom->shutdown()

Request that the guest OS perform a graceful shutdown and
poweroff.

=item $dom->reboot([$flags])

Request that the guest OS perform a graceful shutdown and
optionally restart. The optional C<$flags> parameter is
currently unused and if omitted defaults to zero.

=item $dom->get_max_vcpus()

Return the maximum number of vcpus that are configured
for the domain

=item $dom->attach_device($xml[, $flags])

Hotplug a new device whose configuration is given by C<$xml>,
to the running guest. The optional <$flags> parameter defaults
to 0, but can accept one of the device hotplug flags described
later.

=item $dom->detach_device($xml[, $flags])

Hotunplug a existing device whose configuration is given by C<$xml>,
from the running guest. The optional <$flags> parameter defaults
to 0, but can accept one of the device hotplug flags described
later.

=item $dom->update_device($xml[, $flags])

Update the configuration of an existing device. The new configuration
is given by C<$xml>. The optional <$flags> parameter defaults to
0 but can accept one of the device hotplug flags described later.

=item $data = $dom->block_peek($path, $offset, $size[, $flags)

Peek into the guest disk C<$path>, at byte C<$offset> capturing
C<$size> bytes of data. The returned scalar may contain embedded
NULLs. The optional C<$flags> parameter is currently unused and
if omitted defaults to zero.

=item $data = $dom->memory_peek($offset, $size[, $flags])

Peek into the guest memory at byte C<$offset> virtual address,
capturing C<$size> bytes of memory. The return scalar may
contain embedded NULLs. The optional C<$flags> parameter is
currently unused and if omitted defaults to zero.

=item $flag = $dom->get_autostart();

Return a true value if the guest domain is configured to automatically
start upon boot. Return false, otherwise

=item $dom->set_autostart($flag)

Set the state of the autostart flag, which determines whether the
guest will automatically start upon boot of the host OS

=item $dom->set_vcpus($count, [$flags])

Set the number of virtual CPUs in the guest VM to C<$count>.
The optional C<$flags> parameter can be used to control whether
the setting changes the live config or inactive config.

=item $count = $dom->get_vcpus([$flags])

Get the number of virtual CPUs in the guest VM.
The optional C<$flags> parameter can be used to control whether
to query the setting of the live config or inactive config.

=item $type = $dom->get_scheduler_type()

Return the scheduler type for the guest domain

=item %stats = $dom->block_stats($path)

Fetch the current I/O statistics for the block device given by C<$path>.
The returned hash containins keys for

=item my %params = $dom->get_scheduler_parameters()

Return the set of scheduler tunable parameters for the guest.

=item $dom->set_scheduler_parameters($params)

Update the set of scheduler tunable parameters. The value names for
tunables vary, and can be discovered using the C<get_scheduler_params>
call

=item my $params = $dom->get_memory_parameters()

Return a hash reference containing the set of memory tunable
parameters for the guest. The keys in the hash are one of the
constants MEMORY PARAMETERS described later.

=item $dom->set_memory_parameters($params)

Update the memory tunable parameters for the guest. The
C<$params> should be a hash reference whose keys are one
of the MEMORY PARAMETERS constants.

=over 4

=item C<rd_req>

Number of read requests

=item C<rd_bytes>

Number of bytes read

=item C<wr_req>

Number of write requests

=item C<wr_bytes>

Number of bytes written

=item C<errs>

Some kind of error count

=back

=item $dom->interface_stats($path)

Fetch the current I/O statistics for the block device given by C<$path>.
The returned hash containins keys for

=over 4

=item C<rx_bytes>

Total bytes received

=item C<rx_packets>

Total packets received

=item C<rx_errs>

Total packets received with errors

=item C<rx_drop>

Total packets drop at reception

=item C<tx_bytes>

Total bytes transmitted

=item C<tx_packets>

Total packets transmitted

=item C<tx_errs>

Total packets transmitted with errors

=item C<tx_drop>

Total packets dropped at transmission.

=back

=item $dom->memory_stats($flags=0)

Fetch the current memory statistics for the guest domain. The
C<$flags> parameter is currently unused and can be omitted.
The returned hash containins keys for

=over 4

=item C<swap_in>

Data read from swap space

=item C<swap_out>

Data written to swap space

=item C<major_fault>

Page fault involving disk I/O

=item C<minor_fault>

Page fault not involving disk I/O

=item C<unused>

Memory not used by the system

=item C<available>

Total memory seen by guest

=back

=item %info = $dom->get_security_label()

Fetch information about the security label assigned to the guest
domain. The returned hash has two keys, C<model> gives the name
of the security model in effect (eg C<selinux>), while C<label>
provides the name of the security label applied to the domain.

=item $ddom = $dom->migrate(destcon, flags, dname, uri, bandwidth)

Migrate a domain to an alternative host. The C<destcon> parameter
should be a C<Sys::Virt> connection to the remote target host.
If the C<flags> parameter is zero offline migration will be
performed. The C<Sys::Virt::Domain::MIGRATE_LIVE> constant can be
used to request live migration. The C<dname> parameter allows the
guest to be renamed on the target host, if set to C<undef>, the
domains' current name will be maintained. In normal circumstances,
the source host determines the target hostname from the URI associated
with the C<destcon> connection. If the destination host is multi-homed
it may be necessary to supply an alternate destination hostame
via the C<uri> parameter. The C<bandwidth> parameter allows network
usage to be throttled during migration. If set to zero, no throttling
will be performed. The C<flags>, C<dname>, C<uri> and C<bandwidth>
parameters are all optional, and if omitted default to zero, C<undef>,
C<undef>, and zero respectively.


=item $dom->migrate_to_uri(desturi, flags, dname, uri, bandwidth)

Migrate a domain to an alternative host. The C<destri> parameter
should be a valid libvirt connection URI for the remote target host.
If the C<flags> parameter is zero offline migration will be
performed. The C<Sys::Virt::Domain::MIGRATE_LIVE> constant can be
used to request live migration. The C<dname> parameter allows the
guest to be renamed on the target host, if set to C<undef>, the
domains' current name will be maintained. In normal circumstances,
the source host determines the target hostname from the URI associated
with the C<destcon> connection. If the destination host is multi-homed
it may be necessary to supply an alternate destination hostame
via the C<uri> parameter. The C<bandwidth> parameter allows network
usage to be throttled during migration. If set to zero, no throttling
will be performed. The C<flags>, C<dname>, C<uri> and C<bandwidth>
parameters are all optional, and if omitted default to zero, C<undef>,
C<undef>, and zero respectively.


=item $dom->migrate_set_max_downtime($downtime, $flags)

Set the maximum allowed downtime during migration of the guest. A
longer downtime makes it more likely that migration will complete,
at the cost of longer time blackout for the guest OS at the switch
over point. The C<downtime> parameter is measured in milliseconds.
The C<$flags> parameter is currently unused and defaults to zero.

=item @vcpuinfo = $dom->get_vcpu_info()

Obtain information about the state of all virtual CPUs in a running
guest domain. The returned list will have one element for each vCPU,
where each elements contains a hash reference. The keys in the hash
are, C<number> the vCPU number, C<cpu> the physical CPU on which the
vCPU is currently scheduled, C<cpuTime> the cummulative execution
time of the vCPU, C<state> the running state and C<affinity> giving
the allowed shedular placement. The value for C<affinity> is a
string representing a bitmask against physical CPUs, 8 cpus per
character.

=item $dom->pin_vcpu($vcpu, $mask)

Ping the virtual CPU given by index C<$vcpu> to physical CPUs
given by C<$mask>. The C<$mask> is a string representing a bitmask
against physical CPUs, 8 cpus per character.

=item my $info = $dom->get_job_info()

Returns a hash reference summarising the execution state of the
background job. The elements of the hash are as follows:

=item $dom->abort_job()

Aborts the currently executing job

=item $count = $dom->num_of_snapshots()

Return the number of saved snapshots of the domain

=item @names = $dom->list_snapshot_names()

List the names of all saved snapshots. The names can be
used with the C<lookup_snapshot_by_name>

=item @snapshots = $dom->list_snapshots()

Return a list of all snapshots currently known to the domain. The elements
in the returned list are instances of the L<Sys::Virt::DomainSnapshot> class.

=cut


sub list_snapshots {
    my $self = shift;

    my $nnames = $self->num_of_snapshots();
    my @names = $self->list_snapshot_names($nnames);

    my @snapshots;
    foreach my $name (@names) {
	eval {
	    push @snapshots, Sys::Virt::Domain->_new(connection => $self, name => $name);
	};
	if ($@) {
	    # nada - snapshot went away before we could look it up
	};
    }
    return @snapshots;
}


=item $dom->has_current_snapshot()

Returns a true value if the domain has a currently active snapshot

=item $snapshot = $dom->current_snapshot()

Returns the currently active snapshot for the domain.

=over 4

=item type

The type of job, one of the JOB TYPE constants listed later in
this document.

=item timeElapsed

The elapsed time in milliseconds

=item timeRemaining

The expected remaining time in milliseconds. Only set if the
C<type> is JOB_UNBOUNDED.

=item dataTotal

The total amount of data expected to be processed by the job, in bytes.

=item dataProcessed

The current amount of data processed by the job, in bytes.

=item dataRemaining

The expected amount of data remaining to be processed by the job, in bytes.

=item memTotal

The total amount of mem expected to be processed by the job, in bytes.

=item memProcessed

The current amount of mem processed by the job, in bytes.

=item memRemaining

The expected amount of mem remaining to be processed by the job, in bytes.

=item fileTotal

The total amount of file expected to be processed by the job, in bytes.

=item fileProcessed

The current amount of file processed by the job, in bytes.

=item fileRemaining

The expected amount of file remaining to be processed by the job, in bytes.

=back

=cut


1;

=back

=head1 CONSTANTS

A number of the APIs take a C<flags> parameter. In most cases
passing a value of zero will be satisfactory. Some APIs, however,
accept named constants to alter their behaviour. This section
documents the current known constants.

=head2 DOMAIN STATE

The domain state constants are useful in interpreting the
C<state> key in the hash returned by the C<get_info> method.

=over 4

=item Sys::Virt::Domain::STATE_NOSTATE

The domain is active, but is not running / blocked (eg idle)

=item Sys::Virt::Domain::STATE_RUNNING

The domain is active and running

=item Sys::Virt::Domain::STATE_BLOCKED

The domain is active, but execution is blocked

=item Sys::Virt::Domain::STATE_PAUSED

The domain is active, but execution has been paused

=item Sys::Virt::Domain::STATE_SHUTDOWN

The domain is active, but in the shutdown phase

=item Sys::Virt::Domain::STATE_SHUTOFF

The domain is inactive, and shut down.

=item Sys::Virt::Domain::STATE_CRASHED

The domain is inactive, and crashed.

=back


=head2 DOMAIN CREATION

The following constants can be used to control the behaviour
of domain creation

=over 4

=item Sys::Virt::Domain::START_PAUSED

Keep the guest vCPUs paused after starting the guest

=back


=head2 MEMORY PEEK

The following constants can be used with the C<memory_peek>
method's flags parameter

=over 4

=item Sys::Virt::Domain::MEMORY_VIRTUAL

Indicates that the offset is using virtual memory addressing.

=back


=head2 VCPU STATE

The following constants are useful when interpreting the
virtual CPU run state

=over 4

=item Sys::Virt::Domain::VCPU_OFFLINE

The virtual CPU is not online

=item Sys::Virt::Domain::VCPU_RUNNING

The virtual CPU is executing code

=item Sys::Virt::Domain::VCPU_BLOCKED

The virtual CPU is waiting to be scheduled

=back


=head2 XML DUMP OPTIONS

The following constants are used to control the information
included in the XML configuration dump

=over 4

=item Sys::Virt::Domain::XML_INACTIVE

Report the persistent inactive configuration for the guest, even
if it is currently running.

=item Sys::Virt::Domain::XML_SECURE

Include security sensitive information in the XML dump, such as
passwords.

=back

=head2 DEVICE HOTPLUG OPTIONS

The following constants are used to control device hotplug
operations

=over 4

=item Sys::Virt::Domain::DEVICE_MODIFY_CURRENT

Modify the domain in its current state

=item Sys::Virt::Domain::DEVICE_MODIFY_LIVE

Modify only the live state of the domain

=item Sys::Virt::Domain::DEVICE_MODIFY_CONFIG

Modify only the persistent config of the domain

=back

=head2 MIGRATE OPTIONS

The following constants are used to control how migration
is performed

=over 4

=item Sys::Virt::Domain::MIGRATE_LIVE

Migrate the guest without interrupting its execution on the source
host.

=item Sys::Virt::Domain::MIGRATE_PEER2PEER

Manage the migration process over a direct peer-2-peer connection between
the source and destination host libvirtd daemons.

=item Sys::Virt::Domain::MIGRATE_TUNNELLED

Tunnel the migration data over the libvirt daemon connection, rather
than the native hypervisor data transport. Requires PEER2PEER flag to
be set.

=item Sys::Virt::Domain::MIGRATE_PERSIST_DEST

Make the domain persistent on the destination host, defining its
configuration file upon completion of migration.

=item Sys::Virt::Domain::MIGRATE_UNDEFINE_SOURCE

Remove the domain's persistent configuration after migration
completes successfully.

=item Sys::Virt::Domain::MIGRATE_PAUSED

Do not re-start execution of the guest CPUs on the destination
host after migration completes.

=back


=head2 JOB TYPES

The following constants describe the different background job
types.

=over 4

=item Sys::Virt::Domain::JOB_NONE

No job is active

=item Sys::Virt::Domain::JOB_BOUNDED

A job with a finite completion time is active

=item Sys::Virt::Domain::JOB_UNBOUNDED

A job with an unbounded completion time is active

=item Sys::Virt::Domain::JOB_COMPLETED

The job has finished, but isn't cleaned up

=item Sys::Virt::Domain::JOB_FAILED

The job has hit an error, but isn't cleaned up

=item Sys::Virt::Domain::JOB_CANCELLED

The job was aborted at user request, but isn't cleaned up

=back


=head2 MEMORY PARAMETERS

The following constants are useful when getting/setting
memory parameters for guests

=over 4

=item Sys::Virt::Domain::MEMORY_HARD_LIMIT

The maximum memory the guest can use.

=item Sys::Virt::Domain::MEMORY_SOFT_LIMIT

The memory upper limit enforced during memory contention.

=item Sys::Virt::Domain::MEMORY_MIN_GUARANTEE

The minimum memory guaranteed to be reserved for the guest.

=item Sys::Virt::Domain::MEMORY_SWAP_HARD_LIMIT

The maximum swap the guest can use.

=back

=head2 VCPU FLAGS

The following constants are useful when getting/setting the
VCPU count for a guest

=over 4

=item Sys::Virt::Domain::VCPU_LIVE

Flag to request the live value

=item Sys::Virt::Domain::VCPU_CONFIG

Flag to request the persistent config value

=back

=head2 STATE CHANGE EVENTS

The following constants allow domain state change events to be
interpreted. The events contain both a state change, and a
reason.

=over 4

=item Sys::Virt::Domain::EVENT_DEFINED

Indicates that a persistent configuration has been defined for
the domain.

=over 4

=item Sys::Virt::Domain::EVENT_DEFINED_ADDED

The defined configuration is newly added

=item Sys::Virt::Domain::EVENT_DEFINED_UPDATED

The defined configuration is an update to an existing configuration

=back

=item Sys::Virt::Domain::EVENT_RESUMED

The domain has resumed execution

=over 4

=item Sys::Virt::Domain::EVENT_RESUMED_MIGRATED

The domain resumed because migration has completed. This is
emitted on the destination host.

=item Sys::Virt::Domain::EVENT_RESUMED_UNPAUSED

The domain resumed because the admin unpaused it.

=back

=item Sys::Virt::Domain::EVENT_STARTED

The domain has started running

=over 4

=item Sys::Virt::Domain::EVENT_STARTED_BOOTED

The domain was booted from shutoff state

=item Sys::Virt::Domain::EVENT_STARTED_MIGRATED

The domain started due to an incoming migration

=item Sys::Virt::Domain::EVENT_STARTED_RESTORED

The domain was restored from saved state file

=back

=item Sys::Virt::Domain::EVENT_STOPPED

The domain has stopped running

=over 4

=item Sys::Virt::Domain::EVENT_STOPPED_CRASHED

The domain stopped because guest operating system has crashed

=item Sys::Virt::Domain::EVENT_STOPPED_DESTROYED

The domain stopped because administrator issued a destroy
command.

=item Sys::Virt::Domain::EVENT_STOPPED_FAILED

The domain stopped because of a fault in the host virtualization
environment.

=item Sys::Virt::Domain::EVENT_STOPPED_MIGRATED

The domain stopped because it was migrated to another machine.

=item Sys::Virt::Domain::EVENT_STOPPED_SAVED

The domain was saved to a state file

=item Sys::Virt::Domain::EVENT_STOPPED_SHUTDOWN

The domain stopped due to graceful shutdown of the guest.

=back

=item Sys::Virt::Domain::EVENT_SUSPENDED

The domain has stopped executing, but still exists

=over 4

=item Sys::Virt::Domain::EVENT_SUSPENDED_MIGRATED

The domain has been suspended due to offline migration

=item Sys::Virt::Domain::EVENT_SUSPENDED_PAUSED

The domain has been suspended due to administrator pause
request.

=back

=item Sys::Virt::Domain::EVENT_UNDEFINED

The persistent configuration has gone away

=over 4

=item Sys::Virt::Domain::EVENT_UNDEFINED_REMOVED

The domain configuration has gone away due to it being
removed by administrator.

=back

=back

=head2 EVENT ID CONSTANTS

=over 4

=item Sys::Virt::Domain::EVENT_ID_LIFECYCLE

Domain lifecycle events

=item Sys::Virt::Domain::EVENT_ID_REBOOT

Soft / warm reboot events

=item Sys::Virt::Domain::EVENT_ID_RTC_CHANGE

RTC clock adjustments

=item Sys::Virt::Domain::EVENT_ID_IO_ERROR

File IO errors, typically from disks

=item Sys::Virt::Domain::EVENT_ID_WATCHDOG

Watchdog device triggering

=item Sys::Virt::Domain::EVENT_ID_GRAPHICS

Graphics client connections.

=item Sys::Virt::Domain::EVENT_ID_IO_ERROR_REASON

File IO errors, typically from disks, with a root cause

=back

=head2 IO ERROR EVENT CONSTANTS

These constants describe what action was taken due to the
IO error.

=over 4

=item Sys::Virt::Domain::EVENT_IO_ERROR_NONE

No action was taken, the error was ignored & reported as success to guest

=item Sys::Virt::Domain::EVENT_IO_ERROR_PAUSE

The guest is paused since the error occurred

=item Sys::Virt::Domain::EVENT_IO_ERROR_REPORT

The error has been reported to the guest OS

=back

=head2 WATCHDOG EVENT CONSTANTS

These constants describe what action was taken due to the
watchdog firing

=over 4

=item Sys::Virt::Domain::EVENT_WATCHDOG_NONE

No action was taken, the watchdog was ignored

=item Sys::Virt::Domain::EVENT_WATCHDOG_PAUSE

The guest is paused since the watchdog fired

=item Sys::Virt::Domain::EVENT_WATCHDOG_POWEROFF

The guest is powered off after the watchdog fired

=item Sys::Virt::Domain::EVENT_WATCHDOG_RESET

The guest is reset after the watchdog fired

=item Sys::Virt::Domain::EVENT_WATCHDOG_SHUTDOWN

The guest attempted to gracefully shutdown after the watchdog fired

=item Sys::Virt::Domain::EVENT_WATCHDOG_DEBUG

No action was taken, the watchdog was logged

=back

=head2 GRAPHICS EVENT PHASE CONSTANTS

These constants describe the phase of the graphics connection

=over 4

=item Sys::Virt::Domain::EVENT_GRAPHICS_CONNECT

The initial client connection

=item Sys::Virt::Domain::EVENT_GRAPHICS_INITIALIZE

The client has been authenticated & the connection is running

=item Sys::Virt::Domain::EVENT_GRAPHICS_DISCONNECT

The client has disconnected

=back

=head2 GRAPHICS EVENT ADDRESS CONSTANTS

These constants describe the format of the address

=over 4

=item Sys::Virt::Domain::EVENT_GRAPHICS_ADDRESS_IPV4

An IPv4 address

=item Sys::Virt::Domain::EVENT_GRAPHICS_ADDRESS_IPV6

An IPv6 address

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
