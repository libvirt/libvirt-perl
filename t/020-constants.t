# -*- perl -*-

use strict;
use warnings;
use Test::More tests => 10;

BEGIN {
  use_ok("Sys::Virt") or die;
}

is(Sys::Virt::CRED_USERNAME, 1, "CRED_USERNAME");
is(Sys::Virt::CRED_AUTHNAME, 2, "CRED_AUTHNAME");
is(Sys::Virt::CRED_LANGUAGE, 3, "CRED_LANGUAGE");
is(Sys::Virt::CRED_CNONCE, 4, "CRED_CNONCE");
is(Sys::Virt::CRED_PASSPHRASE, 5, "CRED_PASSPHRASE");
is(Sys::Virt::CRED_ECHOPROMPT, 6, "CRED_ECHOPROMPT");
is(Sys::Virt::CRED_NOECHOPROMPT, 7, "CRED_NOECHOPROMPT");
is(Sys::Virt::CRED_REALM, 8, "CRED_REALM");
is(Sys::Virt::CRED_EXTERNAL, 9, "CRED_EXTERNAL");

