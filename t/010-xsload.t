# -*- perl -*-

use Test::More tests => 3;

BEGIN {
  use_ok("Sys::Virt") or die;
}

my $con = Sys::Virt->new(address => "");

print "Type: ", $con->get_type(), "\n"; 

print "Version: ", $con->get_major_version(), " ", $con->get_minor_version(), " ", $con->get_micro_version(), " ", "\n";

foreach my $dom ($con->list_domains) {
    print "Dom: '", $dom->get_id(), " " , $dom->get_name(), "\n";
    my $info = $dom->get_info;
    foreach (sort { $a cmp $b } keys %{$info}) {
	print "  ", $_, ": ", $info->{$_}, "\n";
    }
    print "Max ", $dom->get_max_memory, "\n";
    print "XML ", $dom->get_xml_description(), "\n";
}
