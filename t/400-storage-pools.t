# -*- perl -*-

use strict;
use warnings;

use Test::More tests => 21;
use XML::XPath;
use XML::XPath::XMLParser;

BEGIN {
        use_ok('Sys::Virt');
        use_ok('Sys::Virt::StoragePool');
}


my $conn = Sys::Virt->new(uri => "test:///default");

isa_ok($conn, "Sys::Virt");


my $nid = $conn->num_of_storage_pools();
is($nid, 1, "1 active storage_pool");

my @netnames = $conn->list_storage_pool_names($nid);
is_deeply(\@netnames, ["default-pool"], "storage_pool names");

my $net = $conn->get_storage_pool_by_name($netnames[0]);
isa_ok($net, "Sys::Virt::StoragePool");

is($net->get_name, "default-pool", "name");
# Can't depend on UUID since its random
#is($net->get_uuid_string, "004b96e1-2d78-c30f-5aa5-f03c87d21e69", "uuid");

my @nets = $conn->list_storage_pools();
is($#nets, 0, "one storage_pool");
isa_ok($nets[0], "Sys::Virt::StoragePool");


my $nname = $conn->num_of_defined_storage_pools();
is($nname, 0, "0 defined storage_pool");

my $xml = "<pool type='dir'>
  <name>wibble</name>
  <uuid>12341234-5678-5678-5678-123412341234</uuid>
  <target>
    <path>/default-pool</path>
  </target>
</pool>";

$net = $conn->define_storage_pool($xml);

$nname = $conn->num_of_defined_storage_pools();
is($nname, 1, "1 defined storage_pool");

my @names = $conn->list_defined_storage_pool_names($nname);
is_deeply(\@names, ["wibble"], "names");

@nets = $conn->list_defined_storage_pools();
is($#nets, 0, "1 defined storage_pool");
isa_ok($nets[0], "Sys::Virt::StoragePool");

$net = $conn->get_storage_pool_by_name("wibble");
isa_ok($net, "Sys::Virt::StoragePool");


$net->create();

my $nids = $conn->num_of_storage_pools();
is($nids, 2, "2 active storage_pools");

my @ids = sort { $a cmp $b } $conn->list_storage_pool_names($nids);
is_deeply(\@ids, ["default-pool", "wibble"], "storage_pool names");

$net->destroy();


$nids = $conn->num_of_storage_pools();
is($nids, 1, "1 active storage_pools");

@ids = $conn->list_storage_pool_names($nids);
is_deeply(\@ids, ["default-pool"], "storage_pool names");

$net = $conn->get_storage_pool_by_name("wibble");

$net->undefine();


$nname = $conn->num_of_defined_storage_pools();
is($nname, 0, "0 defined storage_pool");

@names = $conn->list_defined_storage_pool_names($nname);
is_deeply(\@names, [], "names");

