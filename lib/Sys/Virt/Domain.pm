=pod

=head1 NAME

Sys::Virt - interface to libvirt virtual machine management API

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



1;
