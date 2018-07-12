package Module::Install::PRIVATE::Enable_Verbose_CPAN_Testing;

use strict;
use warnings;

use lib 'inc';

use vars qw( @ISA $VERSION );

use Module::Install::Base;
@ISA = qw( Module::Install::Base );

$VERSION = sprintf "%d.%02d%02d", q/0.1.0/ =~ /(\d+)/g;

our( $ORIG_TEST_VIA_HARNESS );

# ---------------------------------------------------------------------------

sub enable_verbose_cpan_testing {
  my ($self, @args) = @_;

  # Tell Module::Install to include this, since we use it.
  $self->perl_version('5.005');
  $self->include_deps('Module::Install::AutomatedTester', 0);

  # Avoid subroutine redefined errors
  if (!defined(&Module::Install::AutomatedTester::auto_tester)) {
    require Module::Install::AutomatedTester;
  }

  return unless Module::Install::AutomatedTester::auto_tester();

  unless(defined $ORIG_TEST_VIA_HARNESS) {
    $ORIG_TEST_VIA_HARNESS = MY->can('test_via_harness');
    no warnings 'redefine';
    *MY::test_via_harness = \&_force_verbose;
  }
}

sub _force_verbose {
  my($self, $perl, $tests) = @_;

  my $command = MY->$ORIG_TEST_VIA_HARNESS($perl || '$(FULLPERLRUN)', $tests);

  $command =~ s/\$\(TEST_VERBOSE\)/1/;

  return $command;
} 

1;
