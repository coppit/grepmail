#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );
use File::Copy;
use File::Slurp;

my $CAT = perl_with_inc() . qq{ -MTest::Utils -e catbin};

my %tests = (
"$CAT t/mailboxes/non-mailbox.txt.gz | grepmail pattern"
  => 'none',
"$CAT t/mailboxes/non-mailbox.txt.gz | grepmail -E $single_quote\$email =~ /pattern/$single_quote"
  => 'none',
);

my %expected_errors = (
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
  my $stdout_file = shift;
  my $error_expected = shift;

  my $testname = [splitdir($0)]->[-1];
  $testname =~ s#\.t##;

  my $perl = perl_with_inc();

  $test =~ s#\bgrepmail\s#$perl blib/script/grepmail -C $TEMPDIR/cache #g;

  my $test_stdout = catfile($TEMPDIR,"${testname}_$stdout_file.stdout");
  my $test_stderr = catfile($TEMPDIR,"${testname}.stderr");

  system "$test 1>$test_stdout 2>$test_stderr";

  if (!$? && defined $error_expected)
  {
    ok(0,"Did not encounter an error executing the test when one was expected.");
    return;
  }

  if ($? && !defined $error_expected)
  {
    ok(0, "Encountered an error executing the test when one was not expected.\n" .
      "See $test_stdout and $test_stderr.");
    return;
  }

  my $real_stdout = catfile('t','results',$stdout_file);

  # Compare STDERR first on the assumption that if STDOUT is different, STDERR
  # is too and contains something useful.
  Inspect_Stderr($test_stderr);
  Do_Diff($test_stdout,$real_stdout);
}

# ---------------------------------------------------------------------------

sub Inspect_Stderr
{
  my $filename = shift;

  my $stderr = read_file($filename);

  like($stderr, qr/Standard input is not a mailbox/, '"Standard input is not a mailbox" message') or
    diag("See $filename");
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  use Mail::Mbox::MessageParser;

  unless (defined $Mail::Mbox::MessageParser::Config{'programs'}{'gzip'})
  {
    $skip{"$CAT t/mailboxes/non-mailbox.txt.gz | grepmail pattern"}
      = 'gzip support not enabled in Mail::Mbox::MessageParser';
    $skip{"$CAT t/mailboxes/non-mailbox.txt.gz | grepmail -E $single_quote\$email =~ /pattern/$single_quote"}
      = 'gzip support not enabled in Mail::Mbox::MessageParser';
  }

  return %skip;
}
