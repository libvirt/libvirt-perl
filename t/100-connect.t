# -*- perl -*-

use strict;
use warnings;

use Test::More tests => 22;
use XML::XPath;
use XML::XPath::XMLParser;
use Sys::Hostname;

BEGIN {
        use_ok('Sys::Virt');
}


my $conn = Sys::Virt->new(uri => "test:///default");

isa_ok($conn, "Sys::Virt");


my $info = $conn->get_node_info();

is($info->{model}, "i686", "model");
is($info->{cpus}, 16, "cpus");
is($info->{mhz}, 1400, "mhz");
is($info->{sockets}, 2, "sockets");
is($info->{nodes}, 2, "nodes");
is($info->{cores}, 2, "cores");
is($info->{threads}, 2, "threads");
is($info->{memory}, 3145728, "memory");


my $caps = $conn->get_capabilities;

my $xp = XML::XPath->new(xml => $caps);

my $arch = $xp->find("string(/capabilities/host/cpu/arch)");
is($arch, "i686", "host");


my $guestos = $xp->find("string(/capabilities/guest[1]/os_type)");
is($guestos, "linux", "os");
my $guestarch = $xp->find("string(/capabilities/guest[1]/arch/\@name)");
is($guestarch, "i686", "arch");
my $guestword = $xp->find("string(/capabilities/guest[1]/arch/wordsize)");
is($guestword, "32", "wordsize");
my $guesttype = $xp->find("string(/capabilities/guest[1]/arch/domain/\@type)");
is($guesttype, "test", "type");
my $guestpae = $xp->find("count(/capabilities/guest[1]/features/pae)");
is($guestpae,  1, "pae");
my $guestnonpae = $xp->find("count(/capabilities/guest[1]/features/nonpae)");
is($guestnonpae, 1, "nonpae");

my $ver = $conn->get_version();
my $major = $conn->get_major_version();
my $minor = $conn->get_minor_version();
my $micro = $conn->get_micro_version();

is(($ver - (int($ver % 1000000)))/1000000, $major, "major");
is((($ver - $major) - (($ver - $major) % 1000))/ 1000, $minor, "minor");
is(($ver - $major - $minor), $micro, "micro");


my $max = $conn->get_max_vcpus("linux");
is($max, 32, "max cpus");


my $thishost = hostname();
my $host = $conn->get_hostname();
is($host, $thishost, "hostname");
