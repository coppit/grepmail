#!/usr/bin/perl

use strict;

use Test;
use lib 'lib';
use Test::Utils;
use File::Spec::Functions qw( :ALL );

my %tests = (
'grepmail -v Handy t/mailboxes/mailarc-1.txt'
  => ['not_handy','none'],
'grepmail -hbv Handy t/mailboxes/mailarc-1.txt'
  => ['not_header_body_handy','none'],
'grepmail -bv Handy t/mailboxes/mailarc-1.txt'
  => ['not_body_handy','none'],
'grepmail -hv Handy t/mailboxes/mailarc-1.txt'
  => ['not_header_handy','none'],
"grepmail -v -E $single_quote\$email =~ /Handy/$single_quote t/mailboxes/mailarc-1.txt"
  => ['not_handy','none'],
"grepmail -v -E $single_quote\$email_header =~ /Handy/ && \$email_body =~ /Handy/$single_quote t/mailboxes/mailarc-1.txt"
  => ['not_header_body_handy','none'],
"grepmail -Y $single_quote.*$single_quote -bv Handy t/mailboxes/mailarc-1.txt"
  => ['not_header_body_handy','none'],
"grepmail -Y $single_quote.*$single_quote -v Handy t/mailboxes/mailarc-1.txt"
  => ['not_header_handy','none'],
"grepmail -v -E $single_quote\$email_body =~ /Handy/$single_quote t/mailboxes/mailarc-1.txt"
  => ['not_body_handy','none'],
"grepmail -v -E $single_quote\$email_header =~ /Handy/$single_quote t/mailboxes/mailarc-1.txt"
  => ['not_header_handy','none'],
# Unimplemented
"grepmail -Y $single_quote.*$single_quote -bv Handy t/mailboxes/mailarc-1.txt"
  => ['none','none'],
# Unimplemented
"grepmail -Y $single_quote.*$single_quote -v Handy t/mailboxes/mailarc-1.txt"
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


  my $real_stdout = catfile('t','results',$stdout_file);
  my $real_stderr = catfile('t','results',$stderr_file);

  CheckDiffs([$real_stdout,$test_stdout],[$real_stderr,$test_stderr]);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  $skip{"grepmail -Y $single_quote.*$single_quote -bv Handy t/mailboxes/mailarc-1.txt"}
    = 'unimplemented';
  $skip{"grepmail -Y $single_quote.*$single_quote -v Handy t/mailboxes/mailarc-1.txt"}
    = 'unimplemented';

  return %skip;
}

# ---------------------------------------------------------------------------

