=pod

=head1 NAME

Sys::Virt - interface to libvirt virtual machine management API

=cut

package Sys::Virt;

use strict;
use warnings;

use Sys::Virt::Error;
use Sys::Virt::Domain;

our $VERSION = '0.0.1';
require XSLoader;
XSLoader::load('Sys::Virt', $VERSION);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    
    my $address = exists $params{address} ? $params{address} : die "address parameter is required";
    my $readonly = exists $params{readonly} ? $params{readonly} : 0;
    my $self = Sys::Virt::_open($address, $readonly);

    bless $self, $class;
    
    return $self;
}


sub create_domain {
    my $self = shift;
    my $xml = shift;
    
    return Sys::Virt::Domain->_new(connection => $self, xml => $xml);
}


sub list_domains {
    my $self = shift;
    
    my $ids = $self->list_domain_ids();
    
    my @domains;
    foreach my $id (@{$ids}) {
	push @domains, Sys::Virt::Domain->_new(connection => $self, id => $id);
    }
    return @domains;
}

sub get_major_version {
    my $self = shift;
    my $ver = $self->get_version;
    return ($ver - ($ver % 1000000))/1000000;
}


sub get_minor_version {
    my $self = shift;
    my $ver = $self->get_version;
    my $mver = $ver % 1000000;
    return ($mver - ($mver % 1000)) / 1000;
}

sub get_micro_version {
    my $self = shift;
    return $self->get_version % 1000;
}

1;
