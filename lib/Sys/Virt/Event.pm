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

Sys::Virt::Event - An event loop contract

=head1 DESCRIPTION

The C<Sys::Virt::Event> module represents the contract for integrating
libvirt with an event loop. This package is abstract and intended to
be subclassed to provide an actual implementation.

=head1 METHODS

=over 4

=cut

package Sys::Virt::Event;

use strict;
use warnings;


our $eventimpl = undef;


=item register($impl)

Register an event loop implementation. The implementation should be a
instance of a sub-class of the C<Sys::Virt::Event> package.

=cut

sub register {
    my $impl = shift;

    if (!(ref($impl) &&
	  $impl->isa("Sys::Virt::Event"))) {
	die "event implementation must be a subclass of Sys::Virt::Event";
    }

    $eventimpl = $impl;

    Sys::Virt::Event::_register_impl();
}



sub _add_handle {
    $eventimpl->add_handle(@_);
}
sub _update_handle {
    $eventimpl->update_handle(@_);
}
sub _remove_handle {
    $eventimpl->remove_handle(@_);
}
sub _add_timeout {
    $eventimpl->add_timeout(@_);
}
sub _update_timeout {
    $eventimpl->update_timeout(@_);
}
sub _remove_timeout {
    $eventimpl->remove_timeout(@_);
}

=item $self->_run_handle_callback($watch, $fd, $events, $cb, $opaque)

A helper method for executing a callback in response to one of more
C<$events> on the file handle C<$fd>. The C<$watch> number is the
unique idenifier associated with the file descriptor. The C<$cb>
and C<$opaque> parameters are the callback and data registered for
the handle.

=cut

sub _run_handle_callback {
    my $self = shift;
    my $watch = shift;
    my $fd = shift;
    my $events = shift;
    my $cb = shift;
    my $opaque = shift;
    Sys::Virt::Event::_run_handle_callback_helper($watch, $fd, $events, $cb, $opaque);
}

=item $self->_run_timeout_callback($timer, $cb, $opaque)

A helper method for executing a callback in response to the
expiry of a timeout identified by C<$timer>. The C<$cb>
and C<$opaque> parameters are the callback and data registered for
the timeout.

=cut

sub _run_timeout_callback {
    my $self = shift;
    my $timer = shift;
    my $cb = shift;
    my $opaque = shift;
    Sys::Virt::Event::_run_timeout_callback_helper($timer, $cb, $opaque);
}

=item $self->_free_callback_opaque($ff, $opaque)

A helper method for freeing the data associated with a callback.
The C<$ff> and C<$opaque> parameters are the callback and data
registered for the handle/timeout.

=cut

sub _free_callback_opaque {
    my $self = shift;
    my $ff = shift;
    my $opaque = shift;
    Sys::Virt::Event::_free_callback_opaque_helper($ff, $opaque);
}

1;

=back

=head1 CONSTANTS

=head2 FILE HANDLE EVENTS

When integrating with an event loop the following constants
define the file descriptor events

=over 4

=item Sys::Virt::Event::HANDLE_READABLE

The file descriptor has data available for read without blocking

=item Sys::Virt::Event::HANDLE_WRITABLE

The file descriptor has ability to write data without blocking

=item Sys::Virt::Event::HANDLE_ERROR

An error occurred on the file descriptor

=item Sys::Virt::Event::HANDLE_HANGUP

The remote end of the file descriptor closed

=back

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

L<Sys::Virt>,  C<http://libvirt.org>

=cut