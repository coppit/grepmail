#!/usr/bin/perl

use strict;

use Test;
use lib 'lib';
use Test::Utils;

my %tests = (
'grepmail -ibS Free t/mailboxes/mailarc-1.txt'
  => ['ignore_signatures','none'],
'grepmail -S \'So I got Unix\' t/mailboxes/mailarc-1.txt'
  => ['none','none'],
'grepmail -X \'={75,}\' -S \'61 2 9844 5381\' t/mailboxes/mailarc-1.txt'
  => ['none','none'],
# Unimplemented
'grepmail -iS -E \'$email_body =~ /Free/\' t/mailboxes/mailarc-1.txt'
  => ['none','none'],
# Unimplemented
'grepmail -S \'$email =~ /So I got Unix/\' t/mailboxes/mailarc-1.txt'
  => ['none','none'],
# Unimplemented
'grepmail -X \'={75,}\' -S -E \'$email =~ /61 2 9844 5381/\' t/mailboxes/mailarc-1.txt'
  => ['none','none'],
);

my %expected_errors = (
);

mkdir 't/temp', 0700;

plan (tests => scalar (keys %tests));

my %skip = SetSkip(\%tests);

foreach my $test (sort keys %tests) 
{
  print "Running test:\n  $test\n";

  skip("Skip $skip{$test}",1), next if exists $skip{$test};

  TestIt($test, $tests{$test}, $expected_errors{$test});
}

# ---------------------------------------------------------------------------

sub TestIt
{
  my $test = shift;
  my ($stdout_file,$stderr_file) = @{ shift @_ };
  my $error_expected = shift;

  my $testname = $0;
  $testname =~ s/.*\///;
  $testname =~ s/\.t//;

  {
    my @standard_inc = split /###/, `perl -e '\$" = "###";print "\@INC"'`;
    my @extra_inc;
    foreach my $inc (@INC)
    {
      push @extra_inc, $inc unless grep { /^$inc$/ } @standard_inc;
    }

    local $" = ' -I';
    if (@extra_inc)
    {
      $test =~ s#\bgrepmail\s#$^X -I@extra_inc blib/script/grepmail -C t/temp/cache #g;
    }
    else
    {
      $test =~ s#\bgrepmail\s#$^X blib/script/grepmail -C t/temp/cache #g;
    }
  }

  my $test_stdout = "t/temp/${testname}_$stdout_file.stdout";
  my $test_stderr = "t/temp/${testname}_$stderr_file.stderr";

  system "$test 1>$test_stdout 2>$test_stderr";

  if (!$? && defined $error_expected)
  {
    print "Did not encounter an error executing the test when one was expected.\n\n";
    ok(0);
    return;
  }

  if ($? && !defined $error_expected)
  {
    print "Encountered an error executing the test when one was not expected.\n";
    print "See $test_stdout and $test_stderr.\n\n";
    ok(0);
    return;
  }


  my $real_stdout = "t/results/$stdout_file";
  my $real_stderr = "t/results/$stderr_file";

  CheckDiffs([$real_stdout,$test_stdout],[$real_stderr,$test_stderr]);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  $skip{'grepmail -iS -E \'$email_body =~ /Free/\' t/mailboxes/mailarc-1.txt'}
    = 'unimplemented';
  $skip{'grepmail -S \'$email =~ /So I got Unix/\' t/mailboxes/mailarc-1.txt'}
    = 'unimplemented';
  $skip{'grepmail -X \'={75,}\' -S -E \'$email =~ /61 2 9844 5381/\' t/mailboxes/mailarc-1.txt'}
    = 'unimplemented';

  return %skip;
}

# ---------------------------------------------------------------------------

