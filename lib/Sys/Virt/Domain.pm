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
	    if (exists $params{fds}) {
		$self = Sys::Virt::Domain::_create_with_files($con,  $params{xml},
							      $params{fds}, $params{flags});
	    } else {
		$self = Sys::Virt::Domain::_create($con,  $params{xml}, $params{flags});
	    }
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

=item my $hostname = $dom->get_hostname()

Returns a string representing the hostname of the guest

=item my $str = $dom->get_metadata($type, $uri, $flags =0)

Returns the metadata element of type C<$type> associated
with the domain. If C<$type> is C<Sys::Virt::Domain::METADATA_ELEMENT>
then the C<$uri> parameter specifies the XML namespace to
retrieve, otherwise C<$uri> should be C<undef>. The optional
C<$flags> parameter defaults to zero.

=item $dom->set_metadata($type, $val, $key, $uri, $flags=0)

Sets the metadata element of type C<$type> to hold the value
C<$val>. If C<$type> is  C<Sys::Virt::Domain::METADATA_ELEMENT>
then the C<$key> and C<$uri> elements specify an XML namespace
to use, otherwise they should both be C<undef>. The optional
C<$flags> parameter defaults to zero.

=item $dom->is_active()

Returns a true value if the domain is currently running

=item $dom->is_persistent()

Returns a true value if the domain has a persistent configuration
file defined

=item $dom->is_updated()

Returns a true value if the domain is running and has a persistent
configuration file defined that is out of date compared to the
current live config.

=item my $xml = $dom->get_xml_description($flags=0)

Returns an XML document containing a complete description of
the domain's configuration. The optional $flags parameter
controls generation of the XML document, defaulting to 0 if
omitted. It can be one or more of the XML DUMP constants
listed later in this document.

=item my $type = $dom->get_os_type()

Returns a string containing the name of the OS type running
within the domain.

=item $dom->create($flags)

Start a domain whose configuration was previously defined using the
C<define_domain> method in L<Sys::Virt>. The C<$flags> parameter
accepts one of the DOMAIN CREATION constants documented later, and
defaults to 0 if omitted.

=item $dom->create_with_files($fds, $flags)

Start a domain whose configuration was previously defined using the
C<define_domain> method in L<Sys::Virt>. The C<$fds> parameter is an
array of UNIX file descriptors which will be passed to the init
process of the container. This is only supported with container based
virtualization.The C<$flags> parameter accepts one of the DOMAIN
CREATION constants documented later, and defaults to 0 if omitted.

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

=item $dom->pm_wakeup()

Wakeup the guest from power management suspend state

=item $dom->pm_suspend_for_duration($target, $duration, $flags=0)

Tells the guest OS to enter the power management suspend state
identified by C<$target>. The C<$target> parameter should be
one of the NODE SUSPEND CONTANTS listed in C<Sys::Virt>. The
C<$duration> specifies when the guest should automatically
wakeup. The C<$flags> parameter is optional and defaults to
zero.

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

=item $dom->core_dump_format($filename, $format, [, $flags])

Trigger a core dump of the guest virtual machine, saving its memory
image to C<$filename> so it can be analysed by tools such as C<crash>.
The C<$format> parameter is one of the core dump format constants.
The optional C<$flags> flags parameter is currently unused and if
omitted will default to 0.

=over 4

=item Sys::Virt::Domain::CORE_DUMP_FORMAT_RAW

The raw ELF format

=item Sys::Virt::Domain::CORE_DUMP_FORMAT_KDUMP_ZLIB

The zlib compressed ELF format

=item Sys::Virt::Domain::CORE_DUMP_FORMAT_KDUMP_SNAPPY

The snappy compressed ELF format

=item Sys::Virt::Domain::CORE_DUMP_FORMAT_KDUMP_LZO

The lzo compressed ELF format

=back

=item $dom->destroy()

Immediately poweroff the machine. This is equivalent to removing the
power plug. The guest OS is given no time to cleanup / save state.
For a clean poweroff sequence, use the C<shutdown> method instead.

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

=item my ($state, $reason) = $dom->get_state()

Returns an array whose values specify the current state
of the guest, and the reason for it being in that state.
The C<$state> values are the same as for the C<get_info>
API, and the C<$reason> values come from:

=over 4

=item Sys::Virt::Domain::STATE_CRASHED_UNKNOWN

It is not known why the domain has crashed

=item Sys::Virt::Domain::STATE_CRASHED_PANICKED

The domain has crashed due to a kernel panic

=item Sys::Virt::Domain::STATE_NOSTATE_UNKNOWN

It is not known why the domain has no state

=item Sys::Virt::Domain::STATE_PAUSED_DUMP

The guest is paused due to a core dump operation

=item Sys::Virt::Domain::STATE_PAUSED_FROM_SNAPSHOT

The guest is paused due to a snapshot

=item Sys::Virt::Domain::STATE_PAUSED_IOERROR

The guest is paused due to an I/O error

=item Sys::Virt::Domain::STATE_PAUSED_MIGRATION

The guest is paused due to migration

=item Sys::Virt::Domain::STATE_PAUSED_SAVE

The guest is paused due to a save operation

=item Sys::Virt::Domain::STATE_PAUSED_UNKNOWN

It is not known why the domain has paused

=item Sys::Virt::Domain::STATE_PAUSED_USER

The guest is paused at admin request

=item Sys::Virt::Domain::STATE_PAUSED_WATCHDOG

The guest is paused due to the watchdog

=item Sys::Virt::Domain::STATE_PAUSED_SHUTTING_DOWN

The guest is paused while domain shutdown takes place

=item Sys::Virt::Domain::STATE_PAUSED_SNAPSHOT

The guest is paused while a snapshot takes place

=item Sys::Virt::Domain::STATE_PAUSED_CRASHED

The guest is paused due to a kernel panic

=item Sys::Virt::Domain::STATE_RUNNING_BOOTED

The guest is running after being booted

=item Sys::Virt::Domain::STATE_RUNNING_FROM_SNAPSHOT

The guest is running after restore from snapshot

=item Sys::Virt::Domain::STATE_RUNNING_MIGRATED

The guest is running after migration

=item Sys::Virt::Domain::STATE_RUNNING_MIGRATION_CANCELED

The guest is running after migration abort

=item Sys::Virt::Domain::STATE_RUNNING_RESTORED

The guest is running after restore from file

=item Sys::Virt::Domain::STATE_RUNNING_SAVE_CANCELED

The guest is running after save cancel

=item Sys::Virt::Domain::STATE_RUNNING_UNKNOWN

It is not known why the domain has started

=item Sys::Virt::Domain::STATE_RUNNING_UNPAUSED

The guest is running after a resume

=item Sys::Virt::Domain::STATE_RUNNING_WAKEUP

The guest is running after wakeup from power management suspend

=item Sys::Virt::Domain::STATE_RUNNING_CRASHED

The guest was restarted after crashing

=item Sys::Virt::Domain::STATE_BLOCKED_UNKNOWN

The guest is blocked for an unknown reason

=item Sys::Virt::Domain::STATE_SHUTDOWN_UNKNOWN

It is not known why the domain has shutdown

=item Sys::Virt::Domain::STATE_SHUTDOWN_USER

The guest is shutdown due to admin request

=item Sys::Virt::Domain::STATE_SHUTOFF_CRASHED

The guest is shutoff after a crash

=item Sys::Virt::Domain::STATE_SHUTOFF_DESTROYED

The guest is shutoff after being destroyed

=item Sys::Virt::Domain::STATE_SHUTOFF_FAILED

The guest is shutoff due to a virtualization failure

=item Sys::Virt::Domain::STATE_SHUTOFF_FROM_SNAPSHOT

The guest is shutoff after a snapshot

=item Sys::Virt::Domain::STATE_SHUTOFF_MIGRATED

The guest is shutoff after migration

=item Sys::Virt::Domain::STATE_SHUTOFF_SAVED

The guest is shutoff after a save

=item Sys::Virt::Domain::STATE_SHUTOFF_SHUTDOWN

The guest is shutoff due to controlled shutdown

=item Sys::Virt::Domain::STATE_SHUTOFF_UNKNOWN

It is not known why the domain has shutoff

=item Sys::Virt::Domain::STATE_PMSUSPENDED_UNKNOWN

It is not known why the domain was suspended to RAM

=item Sys::Virt::Domain::STATE_PMSUSPENDED_DISK_UNKNOWN

It is not known why the domain was suspended to disk

=back

=item my $info = $dom->get_control_info($flags=0)

Returns a hash reference providing information about
the control channel. The returned keys in the hash
are

=over 4

=item C<state>

One of the CONTROL INFO constants listed later

=item C<details>

Currently unsed, always 0.

=item C<stateTime>

The elapsed time since the control channel entered
the current state.

=back

=item my ($secs, $nsecs) = $dom->get_time($flags=0);

Get the current time of the guest, in seconds and nanoseconds.
The C<$flags> parameter is currently unused and defaults to
zero.

=item $dom->set_time($secs, $nsecs, $flags=0);

Set the current time of the guest, in seconds and nanoseconds.
The C<$flags> parameter accepts one of

=over 4

=item C<Sys::Virt::Domain::TIME_SYNC>

Re-sync domain time from domain's RTC.

=back

=item my @errs = $dom->get_disk_errors($flags=0)

Returns a list of all disk errors that have occurred on
the backing store for the guest's virtual disks. The
returned array elements are hash references, containing
two keys

=over 4

=item C<path>

The path of the disk with an error

=item C<error>

The error type

=back

=item $dom->send_key($keycodeset, $holdtime, \@keycodes, $flags=0)

Sends a sequence of keycodes to the guest domain. The
C<$keycodeset> should be one of the constants listed
later in the KEYCODE SET section. C<$holdtiem> is the
duration, in milliseconds, to keep the key pressed
before releasing it and sending the next keycode.
C<@keycodes> is an array reference containing the list
of keycodes to send to the guest. The elements in the
array should be keycode values from the specified
keycode set. C<$flags> is currently unused.

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

=item $dom->set_memory($mem, $flags)

Set the current memory for the domain to the value C<$mem>. The
value of the C<$mem> parameter is specified in kilobytes. This
must be less than, or equal to the domain's max memory limit.
The C<$flags> parameter can control whether the update affects
the live guest, or inactive config, defaulting to modifying
the current state.

=item $dom->set_memory_stats_period($period, $flags)

Set the period on which guests memory stats are refreshed,
with C<$period> being a value in seconds. The C<$flags>
parameter is currently unused.

=item $dom->shutdown()

Request that the guest OS perform a graceful shutdown and
poweroff. This usually requires some form of cooperation
from the guest operating system, such as responding to an
ACPI signal, or a guest agent process. For an immediate,
forceful poweroff, use the C<destroy> method instead.

=item $dom->reboot([$flags])

Request that the guest OS perform a graceful shutdown and
optionally restart. The optional C<$flags> parameter is
currently unused and if omitted defaults to zero.

=item $dom->reset([$flags])

Perform a hardware reset of the virtual machine. The guest
OS is given no opportunity to shutdown gracefully. The
optional C<$flags> parameter is currently unused and if
omitted defaults to zero.

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

=item $data = $dom->block_peek($path, $offset, $size[, $flags])

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

=item $stats = $dom->block_stats($path)

Fetch the current I/O statistics for the block device given by C<$path>.
The returned hash reference contains keys for

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

=item my $params = $dom->get_scheduler_parameters($flags=0)

Return the set of scheduler tunable parameters for the guest,
as a hash reference. The precise set of keys in the hash
are specific to the hypervisor.

=item $dom->set_scheduler_parameters($params, $flags=0)

Update the set of scheduler tunable parameters. The value names for
tunables vary, and can be discovered using the C<get_scheduler_params>
call

=item my $params = $dom->get_memory_parameters($flags=0)

Return a hash reference containing the set of memory tunable
parameters for the guest. The keys in the hash are one of the
constants MEMORY PARAMETERS described later. The C<$flags>
parameter accepts one or more the CONFIG OPTION constants
documented later, and defaults to 0 if omitted.

=item $dom->set_memory_parameters($params, $flags=0)

Update the memory tunable parameters for the guest. The
C<$params> should be a hash reference whose keys are one
of the MEMORY PARAMETERS constants. The C<$flags>
parameter accepts one or more the CONFIG OPTION constants
documented later, and defaults to 0 if omitted.

=item my $params = $dom->get_blkio_parameters($flags=0)

Return a hash reference containing the set of blkio tunable
parameters for the guest. The keys in the hash are one of the
constants BLKIO PARAMETERS described later. The C<$flags>
parameter accepts one or more the CONFIG OPTION constants
documented later, and defaults to 0 if omitted.

=item $dom->set_blkio_parameters($params, $flags=0)

Update the blkio tunable parameters for the guest. The
C<$params> should be a hash reference whose keys are one
of the BLKIO PARAMETERS constants. The C<$flags>
parameter accepts one or more the CONFIG OPTION constants
documented later, and defaults to 0 if omitted.

=item $stats = $dom->get_block_iotune($disk, $flags=0)

Return a hash reference containing the set of blkio tunable
parameters for the guest disk C<$disk>. The keys in the hash
are one of the constants BLOCK IOTUNE PARAMETERS described later.

=item $dom->set_block_iotune($disk, $params, $flags=0);

Update the blkio tunable parameters for the guest disk C<$disk>. The
C<$params> should be a hash reference whose keys are one
of the BLOCK IOTUNE PARAMETERS constants.

=item my $params = $dom->get_interface_parameters($intf, $flags=0)

Return a hash reference containing the set of interface tunable
parameters for the guest. The keys in the hash are one of the
constants INTERFACE PARAMETERS described later.

=item $dom->set_interface_parameters($intf, $params, $flags=0)

Update the interface tunable parameters for the guest. The
C<$params> should be a hash reference whose keys are one
of the INTERFACE PARAMETERS constants.

=item my $params = $dom->get_numa_parameters($flags=0)

Return a hash reference containing the set of numa tunable
parameters for the guest. The keys in the hash are one of the
constants NUMA PARAMETERS described later. The C<$flags>
parameter accepts one or more the CONFIG OPTION constants
documented later, and defaults to 0 if omitted.

=item $dom->set_numa_parameters($params, $flags=0)

Update the numa tunable parameters for the guest. The
C<$params> should be a hash reference whose keys are one
of the NUMA PARAMETERS constants. The C<$flags>
parameter accepts one or more the CONFIG OPTION constants
documented later, and defaults to 0 if omitted.

=item $dom->block_resize($disk, $newsize, $flags=0)

Resize the disk C<$disk> to have new size C<$newsize> KB. If the disk
is backed by a special image format, the actual resize is done by the
hypervisor. If the disk is backed by a raw file, or block device,
the resize must be done prior to invoking this API call, and it
merely updates the hypervisor's view of the disk size. The following
flags may be used

=over 4

=item Sys::Virt::Domain::BLOCK_RESIZE_BYTES

Treat C<$newsize> as if it were in bytes, rather than KB.

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

=item $info = $dom->get_security_label()

Fetch information about the security label assigned to the guest
domain. The returned hash reference has two keys, C<model> gives
the name of the security model in effect (eg C<selinux>), while
C<label> provides the name of the security label applied to the
domain. This method only returns information about the first
security label. To retrieve all labels, use C<get_security_label_list>.

=item @info = $dom->get_security_label_list()

Fetches information about all security labels assigned to the
guest domain. The elements in the returned array are all
hash references, whose keys are as described for C<get_security_label>.

=item $ddom = $dom->migrate(destcon, \%params, flags=0)

Migrate a domain to an alternative host. The C<destcon> parameter
should be a C<Sys::Virt> connection to the remote target host.
The C<flags> parameter takes one or more of the C<Sys::Virt::Domain::MIGRATE_XXX>
constants described later in this document. The C<%params> parameter is
a hash reference used to set various parameters for the migration
operation, with the following valid keys.

=over 4

=item C<Sys::Virt::Domain::MIGRATE_PARAM_URI>

The URI to use for initializing the domain migration. It takes a
hypervisor specific format. The uri_transports element of the hypervisor
capabilities XML includes details of the supported URI schemes. When
omitted libvirt will auto-generate suitable default URI. It is typically
only necessary to specify this URI if the destination host has multiple
interfaces and a specific interface is required to transmit migration data.

=item C<Sys::Virt::Domain::MIGRATE_PARAM_DEST_NAME>

The name to be used for the domain on the destination host. Omitting
this parameter keeps the domain name the same. This field is only
allowed to be used with hypervisors that support domain renaming
during migration.

=item C<Sys::Virt::Domain::MIGRATE_PARAM_DEST_XML>

The new configuration to be used for the domain on the destination host.
The configuration must include an identical set of virtual devices, to
ensure a stable guest ABI across migration. Only parameters related to
host side configuration can be changed in the XML. Hypervisors which
support this field will forbid migration if the provided XML would cause
a change in the guest ABI. This field cannot be used to rename the domain
during migration (use VIR_MIGRATE_PARAM_DEST_NAME field for that purpose).
Domain name in the destination XML must match the original domain name.

Omitting this parameter keeps the original domain configuration. Using this
field with hypervisors that do not support changing domain configuration
during migration will result in a failure.

=item C<Sys::Virt::Domain::MIGRATE_PARAM_GRAPHICS_URI>

URI to use for migrating client's connection to domain's graphical console
as VIR_TYPED_PARAM_STRING. If specified, the client will be asked to
automatically reconnect using these parameters instead of the automatically
computed ones. This can be useful if, e.g., the client does not have a direct
access to the network virtualization hosts are connected to and needs to
connect through a proxy. The URI is formed as follows:

      protocol://hostname[:port]/[?parameters]

where protocol is either "spice" or "vnc" and parameters is a list of
protocol specific parameters separated by '&'. Currently recognized
parameters are "tlsPort" and "tlsSubject". For example,

      spice://target.host.com:1234/?tlsPort=4567

=item C<Sys::Virt::Domain::MIGRATE_PARAM_BANDWIDTH>

The maximum bandwidth (in MiB/s) that will be used for migration. If
set to 0 or omitted, libvirt will choose a suitable default. Some
hypervisors do not support this feature and will return an error if
this field is used and is not 0.

=item C<Sys::Virt::Domain::MIGRATE_PARAM_LISTEN_ADDRESS>

The address on which to listen for incoming migration connections.
If omitted, libvirt will listen on the wildcard address (0.0.0.0
or ::). This default may be a security risk if guests, or other
untrusted users have the ability to connect to the virtualization
host, thus use of an explicit restricted listen address is recommended.

=back

=item $ddom = $dom->migrate(destcon, flags=0, dname=undef, uri=undef, bandwidth=0)

Migrate a domain to an alternative host. Use of positional parameters
with C<migrate> is deprecated in favour of passing a hash reference
as described above.

=cut

sub migrate {
    my $dom = shift;
    my $destcon = shift;

    if (ref $_[0] &&
	ref $_[0] eq "HASH") {
	my $params = shift;
	my $flags = shift;

	return $dom->_migrate($destcon, $params, $flags);
    } else {
	my $flags = shift;
	my $dname = shift;
	my $uri = shift;
	my $bandwidth = shift;
	my $params = {};

	$params->{&Sys::Virt::Domain::MIGRATE_PARAM_DEST_NAME} = $dname
	    if defined $dname;
	$params->{&Sys::Virt::Domain::MIGRATE_PARAM_URI} = $uri
	    if defined $uri;
	$params->{&Sys::Virt::Domain::MIGRATE_PARAM_BANDWIDTH} = $bandwidth
	    if defined $bandwidth;

	return $dom->_migrate($destcon, $params, $flags);
    }
}


=item $ddom = $dom->migrate2(destcon, dxml, flags, dname, uri, bandwidth)

Migrate a domain to an alternative host. This method is deprecated in
favour of passing a hash ref to C<migrate>.

=cut

sub migrate2 {
    my $dom = shift;
    my $destcon = shift;
    my $dxml = shift;
    my $flags = shift;
    my $dname = shift;
    my $uri = shift;
    my $bandwidth = shift;
    my $params = {};

    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_DEST_XML} = $dxml
	if defined $dxml;
    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_DEST_NAME} = $dname
	if defined $dname;
    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_URI} = $uri
	if defined $uri;
    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_BANDWIDTH} = $bandwidth
	if defined $bandwidth;

    return $dom->_migrate($destcon, $params, $flags);
}


=item $ddom = $dom->migrate_to_uri(destcon, \%params, flags=0)

Migrate a domain to an alternative host. The C<destri> parameter
should be a valid libvirt connection URI for the remote target host.
The C<flags> parameter takes one or more of the C<Sys::Virt::Domain::MIGRATE_XXX>
constants described later in this document. The C<%params> parameter is
a hash reference used to set various parameters for the migration
operation, with the same keys described for the C<migrate> API.

=item $dom->migrate_to_uri(desturi, flags, dname, bandwidth)

Migrate a domain to an alternative host. Use of positional parameters
with C<migrate_to_uri> is deprecated in favour of passing a hash reference
as described above.

=cut

sub migrate_to_uri {
    my $dom = shift;
    my $desturi = shift;

    if (ref $_[0] &&
	ref $_[0] eq "HASH") {
	my $params = shift;
	my $flags = shift;

	return $dom->_migrate_to_uri($desturi, $params, $flags);
    } else {
	my $flags = shift;
	my $dname = shift;
	my $uri = shift;
	my $bandwidth = shift;
	my $params = {};

	$params->{&Sys::Virt::Domain::MIGRATE_PARAM_DEST_NAME} = $dname
	    if defined $dname;
	$params->{&Sys::Virt::Domain::MIGRATE_PARAM_URI} = $uri
	    if defined $uri;
	$params->{&Sys::Virt::Domain::MIGRATE_PARAM_BANDWIDTH} = $bandwidth
	    if defined $bandwidth;

	return $dom->_migrate_to_uri($desturi, $params, $flags);
    }
}


=item $dom->migrate_to_uri2(dconnuri, miguri, dxml, flags, dname, bandwidth)

Migrate a domain to an alternative host. This method is deprecated in
favour of passing a hash ref to C<migrate_to_uri>.

=cut

sub migrate_to_uri2 {
    my $dom = shift;
    my $desturi = shift;
    my $dxml = shift;
    my $flags = shift;
    my $dname = shift;
    my $uri = shift;
    my $bandwidth = shift;
    my $params = {};

    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_DEST_XML} = $dxml
	if defined $dxml;
    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_DEST_NAME} = $dname
	if defined $dname;
    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_URI} = $uri
	if defined $uri;
    $params->{&Sys::Virt::Domain::MIGRATE_PARAM_BANDWIDTH} = $bandwidth
	if defined $bandwidth;

    return $dom->_migrate_to_uri2($desturi, $params, $flags);
}


=item $dom->migrate_set_max_downtime($downtime, $flags)

Set the maximum allowed downtime during migration of the guest. A
longer downtime makes it more likely that migration will complete,
at the cost of longer time blackout for the guest OS at the switch
over point. The C<downtime> parameter is measured in milliseconds.
The C<$flags> parameter is currently unused and defaults to zero.

=item $dom->migrate_set_max_speed($bandwidth, $flags)

Set the maximum allowed bandwidth during migration of the guest.
The C<bandwidth> parameter is measured in MB/second.
The C<$flags> parameter is currently unused and defaults to zero.

=item $bandwidth = $dom->migrate_get_max_speed($flag)

Get the maximum allowed bandwidth during migration fo the guest.
The returned <bandwidth> value is measured in MB/second.
The C<$flags> parameter is currently unused and defaults to zero.

=item $dom->migrate_set_compression_cache($cacheSize, $flags)

Set the maximum allowed compression cache size during migration of
the guest. The C<cacheSize> parameter is measured in bytes.
The C<$flags> parameter is currently unused and defaults to zero.

=item $cacheSize = $dom->migrate_get_compression_cache($flag)

Get the maximum allowed compression cache size during migration of
the guest. The returned <bandwidth> value is measured in bytes.
The C<$flags> parameter is currently unused and defaults to zero.

=item $dom->inject_nmi($flags)

Trigger an NMI in the guest virtual machine. The C<$flags> parameter
is currently unused and defaults to 0.

=item $dom->open_console($st, $devname, $flags)

Open the text console for a serial, parallel or paravirt console
device identified by C<$devname>, connecting it to the stream
C<$st>. If C<$devname> is undefined, the default console will be
opened. C<$st> must be a C<Sys::Virt::Stream> object used for
bi-directional communication with the console. C<$flags> is
currently unused, defaulting to 0.

=item $dom->open_channel($st, $devname, $flags)

Open the text console for a data channel device identified by
C<$devname>, connecting it to the stream C<$st>. C<$st> must
be a C<Sys::Virt::Stream> object used for bi-directional
communication with the channel. C<$flags> is currently unused,
defaulting to 0.

=item $dom->open_graphics($idx, $fd, $flags)

Open the graphics console for a guest, identified by C<$idx>,
counting from 0. The C<$fd> should be a file descriptor for an
anoymous socket pair. The C<$flags> argument should be one of
the constants listed at the end of this document, and defaults
to 0.

=item $fd = $dom->open_graphics_fd($idx, $flags)

Open the graphics console for a guest, identified by C<$idx>,
counting from 0. The C<$flags> argument should be one of the
constants listed at the end of this document, and defaults
to 0. The return value will be a file descriptor connected
to the console which must be closed when no longer needed.
This method is preferred over C<open_graphics> since it will
work correctly under sVirt mandatory access control policies.

=item my $mimetype = $dom->screenshot($st, $screen, $flags)

Capture a screenshot of the virtual machine's monitor. The C<$screen>
parameter controls which monitor is captured when using a multi-head
or multi-card configuration. C<$st> must be a C<Sys::Virt::Stream>
object from which the data can be read. C<$flags> is currently unused
and defaults to 0. The mimetype of the screenshot is returned

=item @vcpuinfo = $dom->get_vcpu_info($flags=0)

Obtain information about the state of all virtual CPUs in a running
guest domain. The returned list will have one element for each vCPU,
where each elements contains a hash reference. The keys in the hash
are, C<number> the vCPU number, C<cpu> the physical CPU on which the
vCPU is currently scheduled, C<cpuTime> the cummulative execution
time of the vCPU, C<state> the running state and C<affinity> giving
the allowed shedular placement. The value for C<affinity> is a
string representing a bitmask against physical CPUs, 8 cpus per
character. To extract the bits use the C<unpack> function with
the C<b*> template. NB The C<state>, C<cpuTime>, C<cpu> values are
only available if using C<$flags> value of 0, and the domain is
currently running; otherwise they will all be set to zero.

=item $dom->pin_vcpu($vcpu, $mask)

Pin the virtual CPU given by index C<$vcpu> to physical CPUs
given by C<$mask>. The C<$mask> is a string representing a bitmask
against physical CPUs, 8 cpus per character.

=item $mask = $dom->get_emulator_pin_info()

Obtain information about the CPU affinity of the emulator process.
The returned C<$mask> is a bitstring against physical CPUs, 8 cpus
per character. To extract the bits use the C<unpack> function with
the C<b*> template.

=item $dom->pin_emulator($newmask, $flags=0)

Pin the emulator threads to the physical CPUs identified by the
affinity in C<$newmask>. The C<$newmask> is a bitstring against
the physical CPUa, 8 cpus per character. To create a suitable
bitstring, use the C<vec> function with a value of C<1> for the
C<BITS> parameter.

=item my @stats = $dom->get_cpu_stats($startCpu, $numCpus, $flags=0)

Requests the guests host physical CPU usage statistics, starting
from host CPU <$startCpu> counting upto C<$numCpus>. If C<$startCpu>
is -1 and C<$numCpus> is 1, then the utilization across all CPUs
is returned. Returns an array of hash references, each element
containing stats for one CPU.

=item my $info = $dom->get_job_info()

Returns a hash reference summarising the execution state of the
background job. The elements of the hash are as follows:

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

=item my ($type, $stats) = $dom->get_job_stats()

Returns an array summarising the execution state of the
background job. The C<$type> value is one of the JOB TYPE
constants listed later in this document. The C<$stats>
value is a hash reference, whose elements are one of the
following constants.

=over 4

=item type

The type of job, one of the JOB TYPE constants listed later in
this document.

=item Sys::Virt::Domain::JOB_TIME_ELAPSED

The elapsed time in milliseconds

=item Sys::Virt::Domain::JOB_TIME_REMAINING

The expected remaining time in milliseconds. Only set if the
C<type> is JOB_UNBOUNDED.

=item Sys::Virt::Domain::JOB_DATA_TOTAL

The total amount of data expected to be processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_DATA_PROCESSED

The current amount of data processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_DATA_REMAINING

The expected amount of data remaining to be processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_MEMORY_TOTAL

The total amount of mem expected to be processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_MEMORY_PROCESSED

The current amount of mem processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_MEMORY_REMAINING

The expected amount of mem remaining to be processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_MEMORY_CONSTANT

The number of pages filled with a constant byte which have
been transferred

=item Sys::Virt::Domain::JOB_MEMORY_NORMAL

The number of pages transferred without any compression

=item Sys::Virt::Domain::JOB_MEMORY_NORMAL_BYTES

The number of bytes transferred without any compression

=item Sys::Virt::Domain::JOB_DISK_TOTAL

The total amount of file expected to be processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_DISK_PROCESSED

The current amount of file processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_DISK_REMAINING

The expected amount of file remaining to be processed by the job, in bytes.

=item Sys::Virt::Domain::JOB_COMPRESSION_CACHE

The size of the compression cache in bytes

=item Sys::Virt::Domain::JOB_COMPRESSION_BYTES

The number of compressed bytes transferred

=item Sys::Virt::Domain::JOB_COMPRESSION_PAGES

The number of compressed pages transferred

=item Sys::Virt::Domain::JOB_COMPRESSION_CACHE_MISSES

The number of changing pages not in compression cache

=item Sys::Virt::Domain::JOB_COMPRESSION_OVERFLOW

The number of changing pages in the compression cache but sent
uncompressed since the compressed page was larger than the
non-compressed page.

=item Sys::Virt::Domain::JOB_DOWNTIME

The number of milliseconds of downtime expected during
migration switchover.

=back

=item $dom->abort_job()

Aborts the currently executing job

=item my $info = $dom->get_block_job_info($path, $flags=0)

Returns a hash reference summarising the execution state of
the block job. The C<$path> parameter should be the fully
qualified path of the block device being changed.

=item $dom->set_block_job_speed($path, $bandwidth, $flags=0)

Change the maximum I/O bandwidth used by the block job that
is currently executing for C<$path>. The C<$bandwidth> argument
is specified in MB/s

=item $dom->abort_block_job($path, $flags=0)

Abort the current job that is executing for the block device
associated with C<$path>

=item $dom->block_pull($path, $bandwith, $flags=0)

Merge the backing files associated with C<$path> into the
top level file. The C<$bandwidth> parameter specifies the
maximum I/O rate to allow in MB/s.

=item $dom->block_rebase($path, $base, $bandwith, $flags=0)

Switch the backing path associated with C<$path> to instead
use C<$base>. The C<$bandwidth> parameter specifies the
maximum I/O rate to allow in MB/s.

=item $dom->block_copy($path, $destxml, $params, $flags=0)

Copy contents of a disk image <$path> into the target volume
described by C<$destxml> which follows the schema of the
<disk> element in the domain XML. The C<$params> parameter
is a hash of optional parameters to control the process

=over 4

=item Sys::Virt::Domain::BLOCK_COPY_BANDWIDTH

The maximum bandwidth in bytes per second.

=item Sys::Virt::Domain::BLOCK_COPY_GRANULARITY

The granularity in bytes of the copy process

=item Sys::Virt::Domain::BLOCK_COPY_BUF_SIZE

The maximum amount of data in flight in bytes.

=back

=item $dom->block_commit($path, $base, $top, $bandwith, $flags=0)

Commit changes there were made to the temporary top level file C<$top>.
Takes all the differences between C<$top> and C<$base> and merge them
into C<$base>. The C<$bandwidth> parameter specifies the
maximum I/O rate to allow in MB/s.

=item $count = $dom->num_of_snapshots()

Return the number of saved snapshots of the domain

=item @names = $dom->list_snapshot_names()

List the names of all saved snapshots. The names can be
used with the C<lookup_snapshot_by_name>

=item @snapshots = $dom->list_snapshots()

Return a list of all snapshots currently known to the domain. The elements
in the returned list are instances of the L<Sys::Virt::DomainSnapshot> class.
This method requires O(n) RPC calls, so the C<list_all_snapshots> method is
recommended as a more efficient alternative.

=cut


sub list_snapshots {
    my $self = shift;

    my $nnames = $self->num_of_snapshots();
    my @names = $self->list_snapshot_names($nnames);

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



=item my @snapshots = $dom->list_all_snapshots($flags)

Return a list of all domain snapshots associated with this domain.
The elements in the returned list are instances of the
L<Sys::Virt::DomainSnapshot> class. The C<$flags> parameter can be
used to filter the list of return domain snapshots.

=item my $snapshot = $dom->get_snapshot_by_name($name)

Return the domain snapshot with a name of C<$name>. The returned object is
an instance of the L<Sys::Virt::DomainSnapshot> class.

=cut

sub get_snapshot_by_name {
    my $self = shift;
    my $name = shift;

    return Sys::Virt::DomainSnapshot->_new(domain => $self, name => $name);
}

=item $dom->has_current_snapshot()

Returns a true value if the domain has a currently active snapshot

=item $snapshot = $dom->current_snapshot()

Returns the currently active snapshot for the domain.

=item $snapshot = $dom->create_snapshot($xml[, $flags])

Create a new snapshot from the C<$xml>. The C<$flags> parameter accepts
the B<SNAPSHOT CREATION> constants listed in C<Sys::Virt::DomainSnapshots>.

=cut

sub create_snapshot {
    my $self = shift;
    my $xml = shift;
    my $flags = shift;

    my $snapshot = Sys::Virt::DomainSnapshot->_new(domain => $self, xml => $xml, flags => $flags);

    return $snapshot;
}

1;

=item $dom->fs_trim($mountPoint, $minimum, $flags=0);

Issue an FS_TRIM command to the device at C<$mountPoint>
to remove chunks of unused space that are at least
C<$minimum> bytes in length. C<$flags> is currently
unused and defaults to zero.

=item $dom->fs_freeze(\@mountPoints, $flags=0);

Freeze all the filesystems associated with the C<@mountPoints>
array reference. If <@mountPoints> is an empty list, then all
filesystems will be frozen. C<$flags> is currently
unused and defaults to zero.

=item $dom->fs_thaw(\@mountPoints, $flags=0);

Thaw all the filesystems associated with the C<@mountPoints>
array reference. If <@mountPoints> is an empty list, then all
filesystems will be thawed. C<$flags> is currently
unused and defaults to zero.

=item $dom->send_process_signal($pid, $signum, $flags=0);

Send the process C<$pid> the signal C<$signum>. The
C<$signum> value must be one of the constants listed
later, not a POSIX or Linux signal value. C<$flags>
is currently unused and defaults to zero.

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

=item Sys::Virt::Domain::STATE_PMSUSPENDED

The domain is active, but in power management suspend state

=back


=head2 CONTROL INFO

The following constants can be used to determine what the
guest domain control channel status is

=over 4

=item Sys::Virt::Domain::CONTROL_ERROR

The control channel has a fatal error

=item Sys::Virt::Domain::CONTROL_OK

The control channel is ready for jobs

=item Sys::Virt::Domain::CONTROL_OCCUPIED

The control channel is busy

=item Sys::Virt::Domain::CONTROL_JOB

The control channel is busy with a job

=back

=head2 DOMAIN CREATION

The following constants can be used to control the behaviour
of domain creation

=over 4

=item Sys::Virt::Domain::START_PAUSED

Keep the guest vCPUs paused after starting the guest

=item Sys::Virt::Domain::START_AUTODESTROY

Automatically destroy the guest when the connection is closed (or fails)

=item Sys::Virt::Domain::START_BYPASS_CACHE

Do not use OS I/O cache if starting a domain with a saved state image

=item Sys::Virt::Domain::START_FORCE_BOOT

Boot the guest, even if there was a saved snapshot

=back


=head2 KEYCODE SETS

The following constants define the set of supported keycode
sets

=over 4

=item Sys::Virt::Domain::KEYCODE_SET_LINUX

The Linux event subsystem keycodes

=item Sys::Virt::Domain::KEYCODE_SET_XT

The original XT keycodes

=item Sys::Virt::Domain::KEYCODE_SET_ATSET1

The AT Set1 keycodes (aka XT)

=item Sys::Virt::Domain::KEYCODE_SET_ATSET2

The AT Set2 keycodes (aka AT)

=item Sys::Virt::Domain::KEYCODE_SET_ATSET3

The AT Set3 keycodes (aka PS2)

=item Sys::Virt::Domain::KEYCODE_SET_OSX

The OS-X keycodes

=item Sys::Virt::Domain::KEYCODE_SET_XT_KBD

The XT keycodes from the Linux Keyboard driver

=item Sys::Virt::Domain::KEYCODE_SET_USB

The USB HID keycode set

=item Sys::Virt::Domain::KEYCODE_SET_WIN32

The Windows keycode set

=item Sys::Virt::Domain::KEYCODE_SET_RFB

The XT keycode set, with the extended scancodes using the
high bit of the first byte, instead of the low bit of the
second byte.

=back

=head2 MEMORY PEEK

The following constants can be used with the C<memory_peek>
method's flags parameter

=over 4

=item Sys::Virt::Domain::MEMORY_VIRTUAL

Indicates that the offset is using virtual memory addressing.

=item Sys::Virt::Domain::MEMORY_PHYSICAL

Indicates that the offset is using physical memory addressing.

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


=head2 OPEN GRAPHICS CONSTANTS

The following constants are used when opening a connection
to the guest graphics server

=over 4

=item Sys::Virt::Domain::OPEN_GRAPHICS_SKIPAUTH

Skip authentication of the client

=back


=head2 OPEN CONSOLE CONSTANTS

The following constants are used when opening a connection
to the guest console

=over 4

=item Sys::Virt::Domain::OPEN_CONSOLE_FORCE

Force opening of the console, disconnecting any other
open session

=item Sys::Virt::Domain::OPEN_CONSOLE_SAFE

Check if the console driver supports safe operations

=back

=head2 OPEN CHANNEL CONSTANTS

The following constants are used when opening a connection
to the guest channel

=over 4

=item Sys::Virt::Domain::OPEN_CHANNEL_FORCE

Force opening of the channel, disconnecting any other
open session

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

=item Sys::Virt::Domain::XML_UPDATE_CPU

Update the CPU model definition to match the current executing
state.

=item Sys::Virt::Domain::XML_MIGRATABLE

Update the XML to allow migration to older versions of libvirt

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

=item Sys::Virt::Domain::DEVICE_MODIFY_FORCE

Force the device to be modified

=back

=head2 MEMORY OPTIONS

The following constants are used to control memory change
operations

=over 4

=item Sys::Virt::Domain::MEM_CURRENT

Modify the current state

=item Sys::Virt::Domain::MEM_LIVE

Modify only the live state of the domain

=item Sys::Virt::Domain::MEM_CONFIG

Modify only the persistent config of the domain

=item Sys::Virt::Domain::MEM_MAXIMUM

Modify the maximum memory value

=back

=head2 CONFIG OPTIONS

The following constants are used to control what configuration
a domain update changes

=over 4

=item Sys::Virt::Domain::AFFECT_CURRENT

Modify the current state

=item Sys::Virt::Domain::AFFECT_LIVE

Modify only the live state of the domain

=item Sys::Virt::Domain::AFFECT_CONFIG

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

=item Sys::Virt::Domain::MIGRATE_NON_SHARED_DISK

Copy the complete contents of the disk images during migration

=item Sys::Virt::Domain::MIGRATE_NON_SHARED_INC

Copy the incrementally changed contents of the disk images
during migration

=item Sys::Virt::Domain::MIGRATE_CHANGE_PROTECTION

Do not allow changes to the virtual domain configuration while
migration is taking place. This option is automatically implied
if doing a peer-2-peer migration.

=item Sys::Virt::Domain::MIGRATE_UNSAFE

Migrate even if the compatibility check indicates the migration
will be unsafe to the guest.

=item Sys::Virt::Domain::MIGRATE_OFFLINE

Migrate the guest config if the guest is not currently running

=item Sys::Virt::Domain::MIGRATE_COMPRESSED

Enable compression of the migration data stream

=item Sys::Virt::Domain::MIGRATE_ABORT_ON_ERROR

Abort if an I/O error occurrs on the disk

=item Sys::Virt::Domain::MIGRATE_AUTO_CONVERGE

Force convergance of the migration operation by
throttling guest runtime

=back

=head2 UNDEFINE CONSTANTS

The following constants can be used when undefining virtual
domain configurations

=over 4

=item Sys::Virt::Domain::UNDEFINE_MANAGED_SAVE

Also remove any managed save image when undefining the virtual
domain

=item Sys::Virt::Domain::UNDEFINE_SNAPSHOTS_METADATA

Also remove any snapshot metadata when undefining the virtual
domain.

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

=item Sys::Virt::Domain::MEMORY_PARAM_UNLIMITED

The value of an unlimited memory parameter

=back


=head2 BLKIO PARAMETERS

The following parameters control I/O tuning for the domain
as a whole

=over 4

=item Sys::Virt::Domain::BLKIO_WEIGHT

The I/O weight parameter

=item Sys::Virt::Domain::BLKIO_DEVICE_WEIGHT

The per-device I/O weight parameter

=item Sys::Virt::Domain::BLKIO_DEVICE_READ_BPS

The per-device I/O bytes read per second

=item Sys::Virt::Domain::BLKIO_DEVICE_READ_IOPS

The per-device I/O operations read per second

=item Sys::Virt::Domain::BLKIO_DEVICE_WRITE_BPS

The per-device I/O bytes write per second

=item Sys::Virt::Domain::BLKIO_DEVICE_WRITE_IOPS

The per-device I/O operations write per second

=back

=head2 BLKIO TUNING PARAMETERS

The following parameters control I/O tuning for an individual
guest disk.

=over 4

=item Sys::Virt::Domain::BLOCK_IOTUNE_TOTAL_BYTES_SEC

The total bytes processed per second.

=item Sys::Virt::Domain::BLOCK_IOTUNE_READ_BYTES_SEC

The bytes read per second.

=item Sys::Virt::Domain::BLOCK_IOTUNE_WRITE_BYTES_SEC

The bytes written per second.

=item Sys::Virt::Domain::BLOCK_IOTUNE_TOTAL_IOPS_SEC

The total I/O operations processed per second.

=item Sys::Virt::Domain::BLOCK_IOTUNE_READ_IOPS_SEC

The I/O operations read per second.

=item Sys::Virt::Domain::BLOCK_IOTUNE_WRITE_IOPS_SEC

The I/O operations written per second.

=back

=head2 SCHEDULER CONSTANTS

=over 4

=item Sys::Virt::Domain::SCHEDULER_CAP

The VM cap tunable

=item Sys::Virt::Domain::SCHEDULER_CPU_SHARES

The CPU shares tunable

=item Sys::Virt::Domain::SCHEDULER_LIMIT

The VM limit tunable

=item Sys::Virt::Domain::SCHEDULER_RESERVATION

The VM reservation tunable

=item Sys::Virt::Domain::SCHEDULER_SHARES

The VM shares tunable

=item Sys::Virt::Domain::SCHEDULER_VCPU_PERIOD

The VCPU period tunable

=item Sys::Virt::Domain::SCHEDULER_VCPU_QUOTA

The VCPU quota tunable

=item Sys::Virt::Domain::SCHEDULER_WEIGHT

The VM weight tunable

=back

=head2 NUMA PARAMETERS

The following constants are useful when getting/setting the
guest NUMA memory policy

=over 4

=item Sys::Virt::Domain::NUMA_MODE

The NUMA policy mode

=item Sys::Virt::Domain::NUMA_NODESET

The NUMA nodeset mask

=back

The following constants are useful when interpreting the
C<Sys::Virt::Domain::NUMA_MODE> parameter value

=over 4

=item Sys::Virt::Domain::NUMATUNE_MEM_STRICT

Allocation is mandatory from the mask nodes

=item Sys::Virt::Domain::NUMATUNE_MEM_PREFERRED

Allocation is preferred from the masked nodes

=item Sys::Virt::Domain::NUMATUNE_MEM_INTERLEAVE

Allocation is interleaved across all masked nods

=back

=head2 INTERFACE PARAMETERS

The following constants are useful when getting/setting the
per network interface tunable parameters

=over 4

=item Sys::Virt::Domain::BANDWIDTH_IN_AVERAGE

The average inbound bandwidth

=item Sys::Virt::Domain::BANDWIDTH_IN_PEAK

The peak inbound bandwidth

=item Sys::Virt::Domain::BANDWIDTH_IN_BURST

The burstable inbound bandwidth

=item Sys::Virt::Domain::BANDWIDTH_OUT_AVERAGE

The average outbound bandwidth

=item Sys::Virt::Domain::BANDWIDTH_OUT_PEAK

The peak outbound bandwidth

=item Sys::Virt::Domain::BANDWIDTH_OUT_BURST

The burstable outbound bandwidth

=back

=head2 VCPU FLAGS

The following constants are useful when getting/setting the
VCPU count for a guest

=over 4

=item Sys::Virt::Domain::VCPU_LIVE

Flag to request the live value

=item Sys::Virt::Domain::VCPU_CONFIG

Flag to request the persistent config value

=item Sys::Virt::Domain::VCPU_CURRENT

Flag to request the current config value

=item Sys::Virt::Domain::VCPU_MAXIMUM

Flag to request adjustment of the maximum vCPU value

=item Sys::Virt::Domain::VCPU_GUEST

Flag to request the guest VCPU mask

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

=item Sys::Virt::Domain::EVENT_RESUMED_FROM_SNAPSHOT

The domain resumed because it was restored from a snapshot

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

=item Sys::Virt::Domain::EVENT_STARTED_FROM_SNAPSHOT

The domain was restored from a snapshot

=item Sys::Virt::Domain::EVENT_STARTED_WAKEUP

The domain was woken up from suspend

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

=item Sys::Virt::Domain::EVENT_STOPPED_FROM_SNAPSHOT

The domain was stopped due to a snapshot

=back

=item Sys::Virt::Domain::EVENT_SHUTDOWN

The domain has shutdown but is not yet stopped

=over 4

=item Sys::Virt::Domain::EVENT_SHUTDOWN_FINISHED

The domain finished shutting down

=back

=item Sys::Virt::Domain::EVENT_SUSPENDED

The domain has stopped executing, but still exists

=over 4

=item Sys::Virt::Domain::EVENT_SUSPENDED_MIGRATED

The domain has been suspended due to offline migration

=item Sys::Virt::Domain::EVENT_SUSPENDED_PAUSED

The domain has been suspended due to administrator pause
request.

=item Sys::Virt::Domain::EVENT_SUSPENDED_IOERROR

The domain has been suspended due to a block device I/O
error.

=item Sys::Virt::Domain::EVENT_SUSPENDED_FROM_SNAPSHOT

The domain has been suspended due to resume from snapshot

=item Sys::Virt::Domain::EVENT_SUSPENDED_WATCHDOG

The domain has been suspended due to the watchdog triggering

=item Sys::Virt::Domain::EVENT_SUSPENDED_RESTORED

The domain has been suspended due to restore from saved state

=item Sys::Virt::Domain::EVENT_SUSPENDED_API_ERROR

The domain has been suspended due to an API error

=back

=item Sys::Virt::Domain::EVENT_UNDEFINED

The persistent configuration has gone away

=over 4

=item Sys::Virt::Domain::EVENT_UNDEFINED_REMOVED

The domain configuration has gone away due to it being
removed by administrator.

=back

=item Sys::Virt::Domain::EVENT_PMSUSPENDED

The domain has stopped running

=over 4

=item Sys::Virt::Domain::EVENT_PMSUSPENDED_MEMORY

The domain has suspend to RAM.

=item Sys::Virt::Domain::EVENT_PMSUSPENDED_DISK

The domain has suspend to Disk.

=back

=item Sys::Virt::Domain::EVENT_CRASHED

The domain has crashed

=over 4

=item Sys::Virt::Domain::EVENT_CRASHED_PANICKED

The domain has crashed due to a kernel panic

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

=item Sys::Virt::Domain::EVENT_ID_CONTROL_ERROR

Errors from the virtualization control channel

=item Sys::Virt::Domain::EVENT_ID_BLOCK_JOB

Completion status of asynchronous block jobs,
identified by source file name.

=item Sys::Virt::Domain::EVENT_ID_BLOCK_JOB_2

Completion status of asynchronous block jobs,
identified by target device name.

=item Sys::Virt::Domain::EVENT_ID_DISK_CHANGE

Changes in disk media

=item Sys::Virt::Domain::EVENT_ID_TRAY_CHANGE

CDROM media tray state

=item Sys::Virt::Domain::EVENT_ID_PMSUSPEND

Power management initiated suspend to RAM

=item Sys::Virt::Domain::EVENT_ID_PMSUSPEND_DISK

Power management initiated suspend to Disk

=item Sys::Virt::Domain::EVENT_ID_PMWAKEUP

Power management initiated wakeup

=item Sys::Virt::Domain::EVENT_ID_BALLOON_CHANGE

Balloon target changes

=item Sys::Virt::Domain::EVENT_ID_DEVICE_REMOVED

Asynchronous guest device removal

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

=item Sys::Virt::Domain::EVENT_GRAPHICS_ADDRESS_UNIX

An UNIX socket path address

=back

=head2 DISK CHANGE EVENT CONSTANTS

These constants describe the reason for a disk change event

=over 4

=item Sys::Virt::Domain::EVENT_DISK_CHANGE_MISSING_ON_START

The disk media was cleared, as its source was missing when attempting to start the guest

=item Sys::Virt::Domain::EVENT_DISK_DROP_MISSING_ON_START

The disk device was dropped, as its source was missing whe  attempting to start the guest

=back

=head2 TRAY CHANGE CONSTANTS

These constants describe the reason for a tray change event

=over 4

=item Sys::Virt::Domain::EVENT_TRAY_CHANGE_CLOSE

The tray was closed

=item Sys::Virt::Domain::EVENT_TRAY_CHANGE_OPEN

The tray was opened

=back

=head2 DOMAIN BLOCK JOB TYPE CONSTANTS

The following constants identify the different types of domain
block jobs

=over 4

=item Sys::Virt::Domain::BLOCK_JOB_TYPE_UNKNOWN

An unknown block job type

=item Sys::Virt::Domain::BLOCK_JOB_TYPE_PULL

The block pull job type

=item Sys::Virt::Domain::BLOCK_JOB_TYPE_COPY

The block copy job type

=item Sys::Virt::Domain::BLOCK_JOB_TYPE_COMMIT

The block commit job type

=item Sys::Virt::Domain::BLOCK_JOB_TYPE_ACTIVE_COMMIT

The block active commit job type

=back

=head2 DOMAIN BLOCK JOB COMPLETION CONSTANTS

The following constants can be used to determine the completion
status of a block job

=over 4

=item Sys::Virt::Domain::BLOCK_JOB_COMPLETED

A successfully completed block job

=item Sys::Virt::Domain::BLOCK_JOB_FAILED

An unsuccessful block job

=item Sys::Virt::Domain::BLOCK_JOB_CANCELED

A block job canceled byy the user

=item Sys::Virt::Domain::BLOCK_JOB_READY

A block job is running

=back

=head2 DOMAIN BLOCK REBASE CONSTANTS

The following constants are useful when rebasing block devices

=over 4

=item Sys::Virt::Domain::BLOCK_REBASE_SHALLOW

Limit copy to top of source backing chain

=item Sys::Virt::Domain::BLOCK_REBASE_REUSE_EXT

Reuse existing external file for copy

=item Sys::Virt::Domain::BLOCK_REBASE_COPY_RAW

Make destination file raw

=item Sys::Virt::Domain::BLOCK_REBASE_COPY

Start a copy job

=item Sys::Virt::Domain::BLOCK_REBASE_RELATIVE

Keep backing chain referenced using relative names

=back

=head2 DOMAIN BLOCK COPY CONSTANTS

The following constants are useful when copying block devices

=over 4

=item Sys::Virt::Domain::BLOCK_COPY_SHALLOW

Limit copy to top of source backing chain

=item Sys::Virt::Domain::BLOCK_COPY_REUSE_EXT

Reuse existing external file for copy

=back

=head2 DOMAIN BLOCK JOB ABORT CONSTANTS

The following constants are useful when aborting job copy jobs

=over 4

=item Sys::Virt::Domain::BLOCK_JOB_ABORT_ASYNC

Request only, do not wait for completion

=item Sys::Virt::Domain::BLOCK_JOB_ABORT_PIVOT

Pivot to mirror when ending a copy job

=back

=head2 DOMAIN BLOCK COMMIT JOB CONSTANTS

The following constants are useful with block commit job types

=over 4

=item Sys::Virt::Domain::BLOCK_COMMIT_DELETE

Delete any files that are invalid after commit

=item Sys::Virt::Domain::BLOCK_COMMIT_SHALLOW

NULL base means next backing file, not whole chain

=item Sys::Virt::Domain::BLOCK_COMMIT_ACTIVE

Allow two phase commit when top is active layer

=item Sys::Virt::Domain::BLOCK_COMMIT_RELATIVE

Keep backing chain referenced using relative names

=back

=head2 DOMAIN SAVE / RESTORE CONSTANTS

The following constants can be used when saving or restoring
virtual machines

=over 4

=item Sys::Virt::Domain::SAVE_BYPASS_CACHE

Do not use OS I/O cache when saving state.

=item Sys::Virt::Domain::SAVE_PAUSED

Mark the saved state as paused to prevent the guest CPUs
starting upon restore.

=item Sys::Virt::Domain::SAVE_RUNNING

Mark the saved state as running to allow the guest CPUs
to start upon restore.

=back

=head2 DOMAIN CORE DUMP CONSTANTS

The following constants can be used when triggering domain
core dumps

=over 4

=item Sys::Virt::Domain::DUMP_LIVE

Do not pause execution while dumping the guest

=item Sys::Virt::Domain::DUMP_CRASH

Crash the guest after completing the core dump

=item Sys::Virt::Domain::DUMP_BYPASS_CACHE

Do not use OS I/O cache when writing core dump

=item Sys::Virt::Domain::DUMP_RESET

Reset the virtual machine after finishing the dump

=item Sys::Virt::Domain::DUMP_MEMORY_ONLY

Only include guest RAM in the dump, not the device
state

=back

=head2 DESTROY CONSTANTS

The following constants are useful when terminating guests
using the C<destroy> API.

=over 4

=item Sys::Virt::Domain::DESTROY_DEFAULT

Destroy the guest using the default approach

=item Sys::Virt::Domain::DESTROY_GRACEFUL

Destroy the guest in a graceful manner

=back

=head2 SHUTDOWN CONSTANTS

The following constants are useful when requesting that a
guest terminate using the C<shutdown> API

=over 4

=item Sys::Virt::Domain::SHUTDOWN_DEFAULT

Shutdown using the hypervisor's default mechanism

=item Sys::Virt::Domain::SHUTDOWN_GUEST_AGENT

Shutdown by issuing a command to a guest agent

=item Sys::Virt::Domain::SHUTDOWN_ACPI_POWER_BTN

Shutdown by injecting an ACPI power button press

=item Sys::Virt::Domain::SHUTDOWN_INITCTL

Shutdown by talking to initctl (containers only)

=item Sys::Virt::Domain::SHUTDOWN_SIGNAL

Shutdown by sending SIGTERM to the init process

=item Sys::Virt::Domain::SHUTDOWN_PARAVIRT

Shutdown by issuing a paravirt power control command

=back

=head2 REBOOT CONSTANTS

The following constants are useful when requesting that a
guest terminate using the C<reboot> API

=over 4

=item Sys::Virt::Domain::REBOOT_DEFAULT

Reboot using the hypervisor's default mechanism

=item Sys::Virt::Domain::REBOOT_GUEST_AGENT

Reboot by issuing a command to a guest agent

=item Sys::Virt::Domain::REBOOT_ACPI_POWER_BTN

Reboot by injecting an ACPI power button press

=item Sys::Virt::Domain::REBOOT_INITCTL

Reboot by talking to initctl (containers only)

=item Sys::Virt::Domain::REBOOT_SIGNAL

Reboot by sending SIGHUP to the init process

=item Sys::Virt::Domain::REBOOT_PARAVIRT

Reboot by issuing a paravirt power control command

=back

=head2 METADATA CONSTANTS

The following constants are useful when reading/writing
metadata about a guest

=over 4

=item Sys::Virt::Domain::METADATA_TITLE

The short human friendly title of the guest

=item Sys::Virt::Domain::METADATA_DESCRIPTION

The long free text description of the guest

=item Sys::Virt::Domain::METADATA_ELEMENT

The structured metadata elements for the guest

=back

=head2 DISK ERROR CONSTANTS

The following constants are useful when interpreting
disk error codes

=over 4

=item Sys::Virt::Domain::DISK_ERROR_NONE

No error

=item Sys::Virt::Domain::DISK_ERROR_NO_SPACE

The host storage has run out of free space

=item Sys::Virt::Domain::DISK_ERROR_UNSPEC

An unspecified error has ocurred.

=back

=head2 MEMORY STATISTIC CONSTANTS

=over 4

=item Sys::Virt::Domain::MEMORY_STAT_SWAP_IN

Swap in

=item Sys::Virt::Domain::MEMORY_STAT_SWAP_OUT

Swap out

=item Sys::Virt::Domain::MEMORY_STAT_MINOR_FAULT

Minor faults

=item Sys::Virt::Domain::MEMORY_STAT_MAJOR_FAULT

Major faults

=item Sys::Virt::Domain::MEMORY_STAT_RSS

Resident memory

=item Sys::Virt::Domain::MEMORY_STAT_UNUSED

Unused memory

=item Sys::Virt::Domain::MEMORY_STAT_AVAILABLE

Available memory

=item Sys::Virt::Domain::MEMORY_STAT_ACTUAL_BALLOON

Actual balloon limit

=back

=head2 DOMAIN LIST CONSTANTS

The following constants can be used when listing domains

=over 4

=item Sys::Virt::Domain::LIST_ACTIVE

Only list domains that are currently active (running, or paused)

=item Sys::Virt::Domain::LIST_AUTOSTART

Only list domains that are set to automatically start on boot

=item Sys::Virt::Domain::LIST_HAS_SNAPSHOT

Only list domains that have a stored snapshot

=item Sys::Virt::Domain::LIST_INACTIVE

Only list domains that are currently inactive (shutoff, saved)

=item Sys::Virt::Domain::LIST_MANAGEDSAVE

Only list domains that have current managed save state

=item Sys::Virt::Domain::LIST_NO_AUTOSTART

Only list domains that are not set to automatically start on boto

=item Sys::Virt::Domain::LIST_NO_MANAGEDSAVE

Only list domains that do not have any managed save state

=item Sys::Virt::Domain::LIST_NO_SNAPSHOT

Only list domains that do not have a stored snapshot

=item Sys::Virt::Domain::LIST_OTHER

Only list domains that are not running, paused or shutoff

=item Sys::Virt::Domain::LIST_PAUSED

Only list domains that are paused

=item Sys::Virt::Domain::LIST_PERSISTENT

Only list domains which have a persistent config

=item Sys::Virt::Domain::LIST_RUNNING

Only list domains that are currently running

=item Sys::Virt::Domain::LIST_SHUTOFF

Only list domains that are currently shutoff

=item Sys::Virt::Domain::LIST_TRANSIENT

Only list domains that do not have a persistent config

=back

=head2 SEND KEY CONSTANTS

The following constants are to be used with the C<send_key>
API

=over 4

=item Sys::Virt::Domain::SEND_KEY_MAX_KEYS

The maximum number of keys that can be sent in a single
call to C<send_key>

=back

=head2 BLOCK STATS CONSTANTS

The following constants provide the names of well known
block stats fields

=over 4

=item Sys::Virt::Domain::BLOCK_STATS_ERRS

The number of I/O errors

=item Sys::Virt::Domain::BLOCK_STATS_FLUSH_REQ

The number of flush requests

=item Sys::Virt::Domain::BLOCK_STATS_FLUSH_TOTAL_TIMES

The time spent processing flush requests

=item Sys::Virt::Domain::BLOCK_STATS_READ_BYTES

The amount of data read

=item Sys::Virt::Domain::BLOCK_STATS_READ_REQ

The number of read requests

=item Sys::Virt::Domain::BLOCK_STATS_READ_TOTAL_TIMES

The time spent processing read requests

=item Sys::Virt::Domain::BLOCK_STATS_WRITE_BYTES

The amount of data written

=item Sys::Virt::Domain::BLOCK_STATS_WRITE_REQ

The number of write requests

=item Sys::Virt::Domain::BLOCK_STATS_WRITE_TOTAL_TIMES

The time spent processing write requests

=back

=head2 CPU STATS CONSTANTS

The following constants provide the names of well known
cpu stats fields

=over 4

=item Sys::Virt::Domain::CPU_STATS_CPUTIME

The total CPU time, including both hypervisor and
vCPU time.

=item Sys::Virt::Domain::CPU_STATS_USERTIME

THe total time in kernel

=item Sys::Virt::Domain::CPU_STATS_SYSTEMTIME

The total time in userspace

=item Sys::Virt::Domain::CPU_STATS_VCPUTIME

The total vCPU time.

=back

=head2 CPU STATS CONSTANTS

The following constants provide the names of well known
schedular parameters

=over 4

=item Sys::Virt::SCHEDULER_EMULATOR_PERIOD

The duration of the time period for scheduling the emulator

=item Sys::Virt::SCHEDULER_EMULATOR_QUOTA

The quota for the emulator in one schedular time period

=back

=head2 DOMAIN STATS FLAG CONSTANTS

The following constants are used as flags when requesting
bulk domain stats from C<Sys::Virt::get_all_domain_stats>.

=over 4

=item Sys::Virt::GET_ALL_STATS_ACTIVE

Include stats for active domains

=item Sys::Virt::GET_ALL_STATS_INACTIVE

Include stats for inactive domains

=item Sys::Virt::GET_ALL_STATS_OTHER

Include stats for other domains

=item Sys::Virt::GET_ALL_STATS_PAUSED

Include stats for paused domains

=item Sys::Virt::GET_ALL_STATS_PERSISTENT

Include stats for persistent domains

=item Sys::Virt::GET_ALL_STATS_RUNNING

Include stats for running domains

=item Sys::Virt::GET_ALL_STATS_SHUTOFF

Include stats for shutoff domains

=item Sys::Virt::GET_ALL_STATS_TRANSIENT

Include stats for transient domains

=item Sys::Virt::GET_ALL_STATS_ENFORCE_STATS

Require that all requested stats fields are returned

=back

=head2 DOMAIN STATS FIELD CONSTANTS

The following constants are used to control which fields
are returned for stats queries.

=over

=item Sys::Virt::Domain::STATS_STATE

General lifecycle state

=back

=head2 PROCESS SIGNALS

The following constants provide the names of signals
which can be sent to guest processes. They mostly
correspond to POSIX signal names.

=over 4

=item Sys::Virt::Domain::PROCESS_SIGNAL_NOP

SIGNOP

=item Sys::Virt::Domain::PROCESS_SIGNAL_HUP

SIGHUP

=item Sys::Virt::Domain::PROCESS_SIGNAL_INT

SIGINT

=item Sys::Virt::Domain::PROCESS_SIGNAL_QUIT

SIGQUIT

=item Sys::Virt::Domain::PROCESS_SIGNAL_ILL

SIGILL

=item Sys::Virt::Domain::PROCESS_SIGNAL_TRAP

SIGTRAP

=item Sys::Virt::Domain::PROCESS_SIGNAL_ABRT

SIGABRT

=item Sys::Virt::Domain::PROCESS_SIGNAL_BUS

SIGBUS

=item Sys::Virt::Domain::PROCESS_SIGNAL_FPE

SIGFPE

=item Sys::Virt::Domain::PROCESS_SIGNAL_KILL

SIGKILL

=item Sys::Virt::Domain::PROCESS_SIGNAL_USR1

SIGUSR1

=item Sys::Virt::Domain::PROCESS_SIGNAL_SEGV

SIGSEGV

=item Sys::Virt::Domain::PROCESS_SIGNAL_USR2

SIGUSR2

=item Sys::Virt::Domain::PROCESS_SIGNAL_PIPE

SIGPIPE

=item Sys::Virt::Domain::PROCESS_SIGNAL_ALRM

SIGALRM

=item Sys::Virt::Domain::PROCESS_SIGNAL_TERM

SIGTERM

=item Sys::Virt::Domain::PROCESS_SIGNAL_STKFLT

SIGSTKFLT

=item Sys::Virt::Domain::PROCESS_SIGNAL_CHLD

SIGCHLD

=item Sys::Virt::Domain::PROCESS_SIGNAL_CONT

SIGCONT

=item Sys::Virt::Domain::PROCESS_SIGNAL_STOP

SIGSTOP

=item Sys::Virt::Domain::PROCESS_SIGNAL_TSTP

SIGTSTP

=item Sys::Virt::Domain::PROCESS_SIGNAL_TTIN

SIGTTIN

=item Sys::Virt::Domain::PROCESS_SIGNAL_TTOU

SIGTTOU

=item Sys::Virt::Domain::PROCESS_SIGNAL_URG

SIGURG

=item Sys::Virt::Domain::PROCESS_SIGNAL_XCPU

SIGXCPU

=item Sys::Virt::Domain::PROCESS_SIGNAL_XFSZ

SIGXFSZ

=item Sys::Virt::Domain::PROCESS_SIGNAL_VTALRM

SIGVTALRM

=item Sys::Virt::Domain::PROCESS_SIGNAL_PROF

SIGPROF

=item Sys::Virt::Domain::PROCESS_SIGNAL_WINCH

SIGWINCH

=item Sys::Virt::Domain::PROCESS_SIGNAL_POLL

SIGPOLL

=item Sys::Virt::Domain::PROCESS_SIGNAL_PWR

SIGPWR

=item Sys::Virt::Domain::PROCESS_SIGNAL_SYS

SIGSYS

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT0

SIGRT0

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT1

SIGRT1

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT2

SIGRT2

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT3

SIGRT3

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT4

SIGRT4

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT5

SIGRT5

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT6

SIGRT6

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT7

SIGRT7

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT8

SIGRT8

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT9

SIGRT9

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT10

SIGRT10

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT11

SIGRT11

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT12

SIGRT12

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT13

SIGRT13

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT14

SIGRT14

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT15

SIGRT15

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT16

SIGRT16

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT17

SIGRT17

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT18

SIGRT18

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT19

SIGRT19

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT20

SIGRT20

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT21

SIGRT21

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT22

SIGRT22

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT23

SIGRT23

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT24

SIGRT24

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT25

SIGRT25

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT26

SIGRT26

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT27

SIGRT27

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT28

SIGRT28

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT29

SIGRT29

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT30

SIGRT30

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT31

SIGRT31

=item Sys::Virt::Domain::PROCESS_SIGNAL_RT32

SIGRT32

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
