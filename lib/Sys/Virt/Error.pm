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

Return the raw error code represented by this error

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

=head1 COPYRIGHT / LICENSE

Copyright (C) 2006 Red Hat

Sys::Virt is distributed under the terms of the GPLv2 or later

=head1 SEE ALSO

L<Sys::Virt::Domain>, L<Sys::Virt>, C<http://libvirt.org>

=cut
