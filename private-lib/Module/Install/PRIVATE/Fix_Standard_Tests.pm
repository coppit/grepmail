package Module::Install::PRIVATE::Fix_Standard_Tests;

use strict;
use warnings;
use File::Slurp;

use vars qw( @ISA $VERSION );

use Module::Install::Base;
@ISA = qw( Module::Install::Base );

$VERSION = sprintf "%d.%02d%02d", q/0.1.0/ =~ /(\d+)/g;

# ---------------------------------------------------------------------------

sub fix_standard_tests {
  my ($self, $script_name, @args) = @_;

  # Update compile test
  {
    my $test = read_file('t/000_standard__compile.t');

    $test =~ s#all_pm_files_ok\(\)#all_pl_files_ok('blib/script/$script_name')# or die "Couldn't update compile test";

    write_file('t/000_standard__compile.t', $test);
  }

  # Update critic test
  {
    my $test = read_file('t/000_standard__perl_critic.t');

    $test =~ s#all_critic_ok\("lib"\)#all_critic_ok("blib")# or die "Couldn't update critic test";

    write_file('t/000_standard__perl_critic.t', $test);
  }
}

1;
