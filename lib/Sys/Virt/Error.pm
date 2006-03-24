=pod

=head1 NAME

Sys::Virt::Error - error handling for libvirt APIs

=cut

package Sys::Virt::Error;

use overload ('""' => 'stringify');

sub stringify {
    my $self = shift;
    
    return "libvirt error code: " . $self->{code} . ", message: " . $self->{message} . ($self->{message} =~ /\n$/ ? "" : "\n");
}


1;
