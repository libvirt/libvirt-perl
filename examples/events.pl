#!/usr/bin/perl


use Sys::Virt;
use Sys::Virt::Event;

my $uri = shift @ARGV;

Sys::Virt::Event::register_default();

my $quit = 0;

my $c = Sys::Virt->new(uri => $uri, readonly => 1);

sub lifecycle_event {
    my $dom = shift;
    my $event = shift;
    my $detail = shift;

    print "$dom $event $detail\n";
}


$c->domain_event_register_any(undef,
			      Sys::Virt::Domain::EVENT_ID_LIFECYCLE,
			      \&lifecycle_event);

$c->register_close_callback(
    sub {
	my $con = shift ;
	my $reason = shift ;
	print "Closed reason=$reason\n";
	$quit = 1;
    });

while (!$quit) {
    Sys::Virt::Event::run_default();
}
