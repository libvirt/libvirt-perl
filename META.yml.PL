# Copyright (C) 2008 Daniel Berrange <dan@berrange.com>

use strict;
use warnings;

die unless (scalar @ARGV == 1);

open SRC, "lib/Sys/Virt.pm"
    or die "lib/Sys/Virt.pm: $!";

our $VERSION;
while (<SRC>) {
    if (/\$VERSION\s*=\s*'(.*)'/) {
	$VERSION=$1;
    }
}
close SRC;

local $/ = undef;
$_ = <DATA>;
s/\@VERSION\@/$VERSION/g;

open SPEC, ">$ARGV[0]" or die "$!";
print SPEC $_;
close SPEC;
__DATA__
--- #YAML:1.0
name:         Sys-Virt
abstract:     Extension for the libvirt library
version:      @VERSION@
author:
  - Daniel P. Berrange <dan@berrange.com>
license: gpl
generated_by: ExtUtils::MakeMaker version 6.30
build_requires:
   Test::More:                    0
   Test::Pod:                     0
   Test::Pod::Coverage:           0
   XML::XPath:                    0
   XML::XPath::XMLParser:         0
   Sys::Hostname:                 0
   Time::HiRes:                   0

resources:
  license: http://www.gnu.org/licenses/gpl.html
  homepage: http://libvirt.org/
  repository: http://hg.berrange.com/libraries/sys-virt--devel
  MailingList: http://www.redhat.com/mailman/listinfo/libvir-list

distribution_type: module

meta-spec:
   version: 1.3
   url: http://module-build.sourceforge.net/META-spec-v1.3.html
