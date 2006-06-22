use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $libvirtver = "0.1.1";
my $stat = system "pkg-config --atleast-version=$libvirtver libvirt";
die "cannot run pkg-config to check libvirt version" if $stat == -1;
die "libvirt >= $libvirtver is required\n" unless $stat == 0;

my $LIBVIRT_LIBS = `pkg-config --libs libvirt`;
my $LIBVIRT_CFLAGS = `pkg-config --cflags libvirt`;

WriteMakefile(
	      'NAME' => 'Sys::Virt',
	      'VERSION_FROM' => 'lib/Sys/Virt.pm',
	      'PREREQ_PM' => {
		  'Test::More'  => 0,
		  },
#    'ABSTRACT_FROM' => 'lib/Sys/Virt.pm',
	      'AUTHOR' => 'Daniel Berrange <dan@berrange.com>',
	      'LIBS' => [$LIBVIRT_LIBS],
	      'DEFINE' => "-DLIBVIRT_API_SUBJECT_TO_CHANGE -DPD_DO_DEBUG=1",
	      'INC' => "-Wall $LIBVIRT_CFLAGS",
	      'depend' => {
		  Sys-Virt.spec => '$(VERSION_FROM)',
		  Makefile => '$(VERSION_FROM)',
	      },
	      'realclean' => {
		  FILES => 'Sys-Virt.spec',
	      },
);

package MY;

sub libscan
  {
    my ($self, $path) = @_;
    ($path =~ /\~$/ || $path =~ m,/CVS/,) ? undef : $path;
  }

sub test {
    my $self = shift;
    my $mm_test = $self->SUPER::test(@_);

    return '
TO_TEST_PM = $(TO_INST_PM:lib/%.pm=blib/test/%.pm.tstamp)

test :: test-syntax

test-syntax: pure_all $(TO_TEST_PM)

blib/test/%.pm.tstamp: lib/%.pm
	@echo -n "Checking $<: "
	#@perl -I blib/lib -c $<
	@podchecker $<
	@mkdir -p `dirname $@`
	@touch $@

' . $mm_test;
  }


__END__
