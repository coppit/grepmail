#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );

my %tests = (
'grepmail Handy -u t/mailboxes/mailarc-1.txt'
  => ['unique_handy','none'],
"grepmail -E $single_quote\$email =~ /Handy/$single_quote -u t/mailboxes/mailarc-1.txt"
  => ['unique_handy','none'],
"grepmail -i $single_quote\$email_body =~ /imagecraft/$single_quote -u t/mailboxes/mailarc-1.txt"
  => ['unique_body_imagecraft','none'],
'grepmail -u t/mailboxes/mailarc-1.txt'
  => ['unique_all_1','none'],
'grepmail -u t/mailboxes/mailarc-3.txt'
  => ['unique_all_2','none'],
'grepmail -bi imagecraft -u t/mailboxes/mailarc-1.txt'
  => ['unique_body','none'],
);

my %expected_errors = (
);

mkdir 't/temp', 0700;

plan (tests => scalar (keys %tests));

my %skip = SetSkip(\%tests);

foreach my $test (sort keys %tests) 
{
  print "Running test:\n  $test\n";

  SKIP:
  {
    skip("$skip{$test}",1) if exists $skip{$test};

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
    my @standard_inc = split /###/, `perl -e '\$" = "###";print "\@INC"'`;
    my @extra_inc;
    foreach my $inc (@INC)
    {
      push @extra_inc, "$single_quote$inc$single_quote"
        unless grep { /^$inc$/ } @standard_inc;
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

  my $test_stdout = catfile('t','temp',"${testname}_$stdout_file.stdout");
  my $test_stderr = catfile('t','temp',"${testname}_$stderr_file.stderr");

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

  CheckDiffs([$real_stdout,$test_stdout],[$real_stderr,$test_stderr]);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  $skip{"grepmail -i $single_quote\$email_body =~ /imagecraft/$single_quote -u t/mailboxes/mailarc-1.txt"} =
    'unimplemented';

  return %skip;
}

# ---------------------------------------------------------------------------

