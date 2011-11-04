use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $libvirtver = "0.9.7";
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
		  'XML::XPath' => 0,
		  },
	      'AUTHOR' => 'Daniel Berrange <dan@berrange.com>',
	      'LIBS' => [$LIBVIRT_LIBS],
	      'INC' => "-Wall $LIBVIRT_CFLAGS",
	      'depend' => {
		  Sys-Virt.spec => '$(VERSION_FROM)',
		  Makefile => '$(VERSION_FROM)',
	      },
              'NO_META' => 1,
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

__END__
