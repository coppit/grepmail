#!/usr/bin/perl

use strict;

use Test;
use lib 'lib';
use Test::Utils;
use File::Spec::Functions qw( :ALL );
use File::Copy;

my %tests = (
'cat t/mailboxes/non-mailbox.txt.gz | grepmail pattern'
  => ['none','not_a_mailbox_pipe'],
"cat t/mailboxes/non-mailbox.txt.gz | grepmail -E $single_quote\$email =~ /pattern/$single_quote"
  => ['none','not_a_mailbox_pipe'],
);

my %expected_errors = (
);

my %localization = (
  'cat t/mailboxes/non-mailbox.txt.gz | grepmail pattern' =>
    { 'stderr' => { 'search' => "[Broken Pipe]\n",
                    'replace' => Broken_Pipe() },
    },
  "cat t/mailboxes/non-mailbox.txt.gz | grepmail -E $single_quote\$email =~ /pattern/$single_quote" =>
    { 'stderr' => { 'search' => "[Broken Pipe]\n",
                    'replace' => Broken_Pipe() },
    },
);

mkdir 't/temp', 0700;

plan (tests => scalar (keys %tests));

my %skip = SetSkip(\%tests);

foreach my $test (sort keys %tests) 
{
  print "Running test:\n  $test\n";

  skip("Skip $skip{$test}",1), next if exists $skip{$test};

  TestIt($test, $tests{$test}, $expected_errors{$test}, $localization{$test});
}

# ---------------------------------------------------------------------------

sub TestIt
{
  my $test = shift;
  my ($stdout_file,$stderr_file) = @{ shift @_ };
  my $error_expected = shift;
  my $localization = shift;

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

  my $modified_stdout = "t/temp/$stdout_file";
  my $modified_stderr = "t/temp/$stderr_file";

  my $real_stdout = catfile('t','results',$stdout_file);
  my $real_stderr = catfile('t','results',$stderr_file);

  if (defined $localization->{'stdout'})
  {
    LocalizeTestOutput($localization->{'stdout'}, $real_stdout, $modified_stdout);
  }
  else
  {
    copy($real_stdout, $modified_stdout);
  }

  if (defined $localization->{'stderr'})
  {
    LocalizeTestOutput($localization->{'stderr'}, $real_stderr, $modified_stderr);
  }
  else
  {
    copy($real_stderr, $modified_stderr);
  }

  CheckDiffs([$modified_stdout,$test_stdout],[$modified_stderr,$test_stderr]);

  unlink $modified_stdout;
  unlink $modified_stderr;
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  use Mail::Mbox::MessageParser;

  unless (defined $Mail::Mbox::MessageParser::PROGRAMS{'gzip'})
  {
    $skip{'cat t/mailboxes/non-mailbox.txt.gz | grepmail pattern'}
      = 'gzip support not enabled in Mail::Mbox::MessageParser';
    $skip{"cat t/mailboxes/non-mailbox.txt.gz | grepmail -E $single_quote\$email =~ /pattern/$single_quote"}
      = 'gzip support not enabled in Mail::Mbox::MessageParser';
  }

  return %skip;
}

# ---------------------------------------------------------------------------

sub LocalizeTestOutput
{
  my $search_replace = shift;
  my $original_file = shift;
  my $new_file = shift;

  open REAL, $original_file or die $!;
  local $/ = undef;
  my $original = <REAL>;
  close REAL;

  my $new = $original;
  $new =~ s/\Q$search_replace->{'search'}\E/$search_replace->{'replace'}/gx;

  open REAL, ">$new_file";
  binmode REAL;
  print REAL $new;
  close REAL;
}

# ---------------------------------------------------------------------------

