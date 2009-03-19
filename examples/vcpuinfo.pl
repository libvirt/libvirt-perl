# -*- perl -*-
use strict;
use warnings;
use Sys::Virt;

my $addr = @ARGV ? shift @ARGV : "";
print "Addr $addr\n";
my $con = Sys::Virt->new(address => $addr, readonly => 1);

print "VMM type: ", $con->get_type(), "\n";

foreach my $dom (sort { $a->get_id <=> $b->get_id } $con->list_domains) {
    print "Domain: {\n";
    print "  ID: ", $dom->get_id(), " '" , $dom->get_name(), "'\n";
    print "  UUID: ", $dom->get_uuid_string(), "\n";
    my $nodeinfo = $con->get_node_info;
    my @info = $dom->get_vcpu_info;

    foreach my $info (@info) {
	print "  VCPU: {\n";
	foreach (sort { $a cmp $b } keys %{$info}) {
	    if ($_ eq "affinity") {
		print "    ", $_, ": ";
		my @mask = split //, $info->{$_};
		for (my $p = 0 ; $p < $nodeinfo->{cpus} ; $p++) {
		    print ((ord($mask[$p/8]) & (1 << ($p % 8))) ? 1 : 0);
		}
		print "\n";
	    } else {
		print "    ", $_, ": ", $info->{$_}, "\n";
	    }
	}
	print "  }\n";
    }
    print "}\n";
}
