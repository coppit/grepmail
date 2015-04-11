#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );
use Config;

my $path_to_perl = $Config{perlpath};

my %tests = (
'grepmail Handy -d "before July 9 1998" t/mailboxes/mailarc-1.txt'
  => ['date_2','none'],
'grepmail -d "before July 15 1998" t/mailboxes/mailarc-1.txt'
  => ['date_1','none'],
'grepmail -d "after armageddon" Handy t/mailboxes/mailarc-1.txt'
  => ['none','invalid_date_1'],
'grepmail -d "before 7/15/1998" t/mailboxes/mailarc-2.txt'
  => ['date_3','none'],
'grepmail -d "" t/mailboxes/mailarc-2.txt'
  => ['none','none'],
"grepmail -E $single_quote\$email =~ /Handy/$single_quote -d \"before July 9 1998\" t/mailboxes/mailarc-1.txt"
  => ['date_2','none'],
"grepmail -d \"after armageddon\" -E $single_quote\$email =~ /Handy/$single_quote t/mailboxes/mailarc-1.txt"
  => ['none','invalid_date_1'],
'grepmail -d "Aug 1998" t/mailboxes/mailarc-1.txt'
  => ['date_august','none'],
);

my %expected_errors = (
'grepmail -d "after armageddon" Handy t/mailboxes/mailarc-1.txt' 
  => 1,
"grepmail -d \"after armageddon\" -E $single_quote\$email =~ /Handy/$single_quote t/mailboxes/mailarc-1.txt"
  => 1,
);

plan tests => scalar (keys %tests) * 2;

my %skip = SetSkip(\%tests);

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

  {
    my @standard_inc = split /###/, `$path_to_perl -e '\$" = "###";print "\@INC"'`;
    my @extra_inc;
    foreach my $inc (@INC)
    {
      push @extra_inc, "$single_quote$inc$single_quote"
        unless grep { /^$inc$/ } @standard_inc;
    }

    local $" = ' -I';
    if (@extra_inc)
    {
      $test =~ s#\bgrepmail\s#$path_to_perl -I@extra_inc blib/script/grepmail -C $TEMPDIR/cache #g;
    }
    else
    {
      $test =~ s#\bgrepmail\s#$path_to_perl blib/script/grepmail -C $TEMPDIR/cache #g;
    }
  }

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

  Do_Diff($test_stdout,$real_stdout);
  Do_Diff($test_stderr,$real_stderr);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  return %skip;
}

# ---------------------------------------------------------------------------

