# -*- perl -*-

use strict;
use warnings;

use Test::More tests => 22;
use XML::XPath;
use XML::XPath::XMLParser;

BEGIN {
        use_ok('Sys::Virt');
        use_ok('Sys::Virt::Network');
}


my $conn = Sys::Virt->new(uri => "test:///default");

isa_ok($conn, "Sys::Virt");


my $nid = $conn->num_of_networks();
is($nid, 1, "1 active network");

my @netnames = $conn->list_network_names($nid);
is_deeply(\@netnames, ["default"], "network names");

my $net = $conn->get_network_by_name($netnames[0]);
isa_ok($net, "Sys::Virt::Network");

is($net->get_name, "default", "name");
is($net->get_uuid_string, "004b96e1-2d78-c30f-5aa5-f03c87d21e69", "uuid");

my @nets = $conn->list_networks();
is($#nets, 0, "one network");
isa_ok($nets[0], "Sys::Virt::Network");


my $nname = $conn->num_of_defined_networks();
is($nname, 0, "0 defined network");

my $xml = "<network>
  <name>wibble</name>
  <uuid>12341234-5678-5678-5678-123412341234</uuid>
  <forward dev='eth0'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.2' end='192.168.100.25'/>
    </dhcp>
  </ip>
</network>";


$net = $conn->define_network($xml);
# XXX hack - libvirt bug - test driver starts the defined net
$net->destroy();

$nname = $conn->num_of_defined_networks();
is($nname, 1, "1 defined network");

my @names = $conn->list_defined_network_names($nname);
is_deeply(\@names, ["wibble"], "names");

@nets = $conn->list_defined_networks();
is($#nets, 0, "1 defined network");
isa_ok($nets[0], "Sys::Virt::Network");

$net = $conn->get_network_by_name("wibble");
isa_ok($net, "Sys::Virt::Network");


$net->create();

my $nids = $conn->num_of_networks();
is($nids, 2, "2 active networks");

my @ids = sort { $a cmp $b } $conn->list_network_names($nids);
is_deeply(\@ids, ["default", "wibble"], "network names");

$net->destroy();


$nids = $conn->num_of_networks();
is($nids, 1, "1 active networks");

@ids = $conn->list_network_names($nids);
is_deeply(\@ids, ["default"], "network names");

$net = $conn->get_network_by_name("wibble");

$net->undefine();


$nname = $conn->num_of_defined_networks();
is($nname, 0, "0 defined network");

@names = $conn->list_defined_network_names($nname);
is_deeply(\@names, [], "names");

