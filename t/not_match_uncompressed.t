#!/usr/bin/perl

use strict;
use warnings 'all';

use Test;
use Test::Utils;

my %tests = (
'grepmail -v Handy t/mailboxes/mailarc-1.txt'
  => ['not_handy','none'],
'grepmail -hbv Handy t/mailboxes/mailarc-1.txt'
  => ['not_header_body_handy','none'],
'grepmail -bv Handy t/mailboxes/mailarc-1.txt'
  => ['not_body_handy','none'],
'grepmail -hv Handy t/mailboxes/mailarc-1.txt'
  => ['not_header_handy','none'],
'grepmail -v -E \'$email =~ /Handy/\' t/mailboxes/mailarc-1.txt'
  => ['not_handy','none'],
'grepmail -v -E \'$email_header =~ /Handy/ && $email_body =~ /Handy/\' t/mailboxes/mailarc-1.txt'
  => ['not_header_body_handy','none'],
'grepmail -Y \'.*\' -bv Handy t/mailboxes/mailarc-1.txt'
  => ['not_header_body_handy','none'],
'grepmail -Y \'.*\' -v Handy t/mailboxes/mailarc-1.txt'
  => ['not_header_handy','none'],
'grepmail -v -E \'$email_body =~ /Handy/\' t/mailboxes/mailarc-1.txt'
  => ['not_body_handy','none'],
'grepmail -v -E \'$email_header =~ /Handy/\' t/mailboxes/mailarc-1.txt'
  => ['not_header_handy','none'],
# Unimplemented
'grepmail -Y \'.*\' -bv Handy t/mailboxes/mailarc-1.txt'
  => ['none','none'],
# Unimplemented
'grepmail -Y \'.*\' -v Handy t/mailboxes/mailarc-1.txt'
  => ['none','none'],
);

my %expected_errors = (
);

mkdir 't/temp';

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

  $test =~ s#\bgrepmail\s#$^X blib/script/grepmail #g;

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

  $skip{'grepmail -Y \'.*\' -bv Handy t/mailboxes/mailarc-1.txt'}
    = 'unimplemented';
  $skip{'grepmail -Y \'.*\' -v Handy t/mailboxes/mailarc-1.txt'}
    = 'unimplemented';

  return %skip;
}

# ---------------------------------------------------------------------------

