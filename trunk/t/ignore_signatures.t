#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );

my %tests = (
'grepmail -ibS Free t/mailboxes/mailarc-1.txt'
  => ['ignore_signatures','none'],
"grepmail -S ${single_quote}So I got Unix$single_quote t/mailboxes/mailarc-1.txt"
  => ['none','none'],
"grepmail -X $single_quote={75,}$single_quote -S ${single_quote}61 2 9844 5381$single_quote t/mailboxes/mailarc-1.txt"
  => ['none','none'],
# Unimplemented
"grepmail -iS -E $single_quote\$email_body =~ /Free/$single_quote t/mailboxes/mailarc-1.txt"
  => ['none','none'],
# Unimplemented
"grepmail -S $single_quote\$email =~ /So I got Unix/$single_quote t/mailboxes/mailarc-1.txt"
  => ['none','none'],
# Unimplemented
"grepmail -X $single_quote\={75,}$single_quote -S -E $single_quote\$email =~ /61 2 9844 5381/$single_quote t/mailboxes/mailarc-1.txt"
  => ['none','none'],
'grepmail -ibS Free t/mailboxes/mailarc-1-dos.txt'
  => ['ignore_signatures_dos','none'],
);

my %expected_errors = (
);

mkdir 't/temp', 0700;

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

  Do_Diff($real_stdout,$test_stdout);
  Do_Diff($real_stderr,$test_stderr);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  $skip{"grepmail -iS -E $single_quote\$email_body =~ /Free/$single_quote t/mailboxes/mailarc-1.txt"}
    = 'unimplemented';
  $skip{"grepmail -S $single_quote\$email =~ /So I got Unix/$single_quote t/mailboxes/mailarc-1.txt"}
    = 'unimplemented';
  $skip{"grepmail -X $single_quote={75,}$single_quote -S -E $single_quote\$email =~ /61 2 9844 5381/$single_quote t/mailboxes/mailarc-1.txt"}
    = 'unimplemented';

  return %skip;
}

# ---------------------------------------------------------------------------

