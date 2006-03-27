# -*- perl -*-

use Sys::Virt;

my $con = Sys::Virt->new(address => "", readonly => 1);

print "VMM yype: ", $con->get_type(), "\n"; 

print "libvirt Version: ", $con->get_major_version(), ".", $con->get_minor_version(), ".", $con->get_micro_version(), "\n";
foreach my $dom (sort { $a->get_id <=> $b->get_id } $con->list_domains) {
    print "Domain: ", $dom->get_id(), " " , $dom->get_name(), "\n";
    print "  UUID: ", $dom->get_uuid(), "\n"; 
    my $info = $dom->get_info;
    foreach (sort { $a cmp $b } keys %{$info}) {
	print "  ", $_, ": ", $info->{$_}, "\n";
    }
}
