package Module::Install::PRIVATE::Fix_Standard_Tests;

use strict;
use warnings;

use vars qw( @ISA $VERSION );

use Module::Install::Base;
@ISA = qw( Module::Install::Base );

$VERSION = sprintf "%d.%02d%02d", q/0.1.0/ =~ /(\d+)/g;

# ---------------------------------------------------------------------------

sub fix_standard_tests {
  my ($self, $script_name, @args) = @_;

  $self->include_deps('File::Slurper', 0);

  require File::Slurper;
  File::Slurper->import('read_text', 'write_text');

  # Update compile test
  {
    my $test = read_text('t/000_standard__compile.t', undef, 1);

    $test =~ s#all_pm_files_ok\(\)#all_pl_files_ok('blib/script/$script_name')# or die "Couldn't update compile test";

    write_text('t/000_standard__compile.t', $test, undef, 1);
  }

  # Update critic test
  {
    my $test = read_text('t/000_standard__perl_critic.t', undef, 1);

    $test =~ s#all_critic_ok\("lib"\)#all_critic_ok("blib")# or die "Couldn't update critic test";

    write_text('t/000_standard__perl_critic.t', $test, undef, 1);
  }
}

1;
