#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );

my %tests = (
'grepmail -d "before 1st Tuesday in July 1998" t/mailboxes/mailarc-1.txt'
  => ['date_manip','none'],
'grepmail -d "after armageddon" pattern t/mailboxes/mailarc-1.txt'
  => ['none','invalid_date_1'],
"grepmail -d \"after armageddon\" -E $single_quote\$email =~ /pattern/$single_quote t/mailboxes/mailarc-1.txt"
  => ['none','invalid_date_1'],
"grepmail -d \"1st Tuesday in July 1998\" . t/mailboxes/mailarc-1.txt"
  => ['sep_7_1998','none'],
);

my %expected_errors = (
'grepmail -d "after armageddon" pattern t/mailboxes/mailarc-1.txt'
  => 1,
"grepmail -d \"after armageddon\" -E $single_quote\$email =~ /pattern/$single_quote t/mailboxes/mailarc-1.txt"
  => 1,
);

plan tests => scalar (keys %tests) * 2 + 1;

my %skip = SetSkip(\%tests);

SKIP:
{
  print "Checking Date::Manip::Date_TimeZone()\n";

  skip("Date::Manip not installed",1) unless Module_Installed('Date::Manip');

  # Date::Manip prior to 5.39 nukes the PATH. Save and restore it to avoid
  # problems.
  my $path = $ENV{PATH};
  require Date::Manip;
  $ENV{PATH} = $path;

  if (eval 'Date::Manip::Date_TimeZone()')
  {
    ok(1);
  }
  else
  {
    print <<EOF;

WARNING: Your time zone is not recognized by Date::Manip. It is likely
that many test cases related to dates will fail. See the README for more
information on how to resolve this problem.

EOF
    ok(0);
  }
}

# So that the tests will work consistently across timezones
$ENV{'TZ'} = 'EST';

foreach my $test (sort keys %tests) 
{
  print "Running test:\n  $test\n";

  SKIP:
  {
    skip("$skip{$test}",2) if exists $skip{$test};

    TestIt($test, $tests{$test}, $expected_errors{$test});
  }
}

# ---------------------------------------------------------------------------

sub TestIt
{
  my $test = shift;
  my ($stdout_file,$stderr_file) = @{ shift @_ };
  my $error_expected = shift;

  my $testname = [splitdir($0)]->[-1];
  $testname =~ s#\.t##;

  my $perl = perl_with_inc();

  $test =~ s#\bgrepmail\s#$perl blib/script/grepmail -C $TEMPDIR/cache #g;

  my $test_stdout = catfile($TEMPDIR,"${testname}_$stdout_file.stdout");
  my $test_stderr = catfile($TEMPDIR,"${testname}_$stderr_file.stderr");

  system "$test 1>$test_stdout 2>$test_stderr";

  if (!$? && defined $error_expected)
  {
    ok(0,"Did not encounter an error executing the test when one was expected.\n\n");
    return;
  }

  if ($? && !defined $error_expected)
  {
    ok(0, "Encountered an error executing the test when one was not expected.\n" .
      "See $test_stdout and $test_stderr.\n\n");
    return;
  }

  my $real_stdout = catfile('t','results',$stdout_file);
  my $real_stderr = catfile('t','results',$stderr_file);

  # Compare STDERR first on the assumption that if STDOUT is different, STDERR
  # is too and contains something useful.
  Do_Diff($test_stderr,$real_stderr);
  Do_Diff($test_stdout,$real_stdout);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  foreach my $test (keys %tests)
  {
    $skip{$test} = 'Date::Manip not installed'
      unless Module_Installed('Date::Manip');
  }

  return %skip;
}

# ---------------------------------------------------------------------------

