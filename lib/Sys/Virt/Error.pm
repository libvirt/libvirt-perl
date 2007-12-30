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

Sys::Virt::Error - error object for libvirt APIs

=head1 DESCRIPTION

The C<Sys::Virt::Error> class provides an encoding of the
libvirt errors. Instances of this object can be thrown by
pretty much any of the Sys::Virt APIs.

=head1 METHODS

=over 4

=cut

package Sys::Virt::Error;

use strict;
use warnings;
use overload ('""' => 'stringify');

=item $err->stringify

Convert the object into string format suitable for printing on a
console to inform a user of the error.

=cut

sub stringify {
    my $self = shift;

    return "libvirt error code: " . $self->{code} . ", message: " . $self->{message} . ($self->{message} =~ /\n$/ ? "" : "\n");
}

=item my $code = $err->code

Return the raw error code represented by this error.

=cut

sub code {
    my $self = shift;
    return $self->{code}
}

=item my $msg = $err->message

Return an informative message describing the error condition.

=cut

sub message {
    my $self = shift;
    return $self->{code}
}


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

L<Sys::Virt::Domain>, L<Sys::Virt>, C<http://libvirt.org>

=cut
