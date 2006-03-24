# -*- perl -*-

use Sys::Virt;

if (@ARGV != 1) {
    print STDERR "syntax: $0 DOMAIN-NAME\n";
    exit 1;
}

my $con = Sys::Virt->new(address => "", readonly => 1);

my $name = shift @ARGV;

my $dom = $con->get_domain_by_name($name);

print $dom->get_xml_description(), "\n";

