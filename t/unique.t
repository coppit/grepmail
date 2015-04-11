#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );
use Config;

my $path_to_perl = $Config{perlpath};

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

  $skip{"grepmail -i $single_quote\$email_body =~ /imagecraft/$single_quote -u t/mailboxes/mailarc-1.txt"} =
    'unimplemented';

  return %skip;
}

# ---------------------------------------------------------------------------

