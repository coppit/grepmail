#!/usr/bin/perl

use strict;

use Test;
use lib 'lib';
use Test::Utils;
use File::Copy;

my %tests = (
'grepmail pattern no_such_file'
  => ['none','no_such_file'],
'cat no_such_file 2>/dev/null | grepmail pattern'
  => ['none','no_data'],
'grepmail -E \'$email =~ /pattern/\' no_such_file'
  => ['none','no_such_file'],
'cat no_such_file 2>/dev/null | grepmail -E \'$email =~ /pattern/\''
  => ['none','no_data'],
);

my %expected_errors = (
'cat no_such_file 2>/dev/null | grepmail pattern' => 1,
'cat no_such_file 2>/dev/null | grepmail -E \'$email =~ /pattern/\'' => 1,
);

my %localization = (
  'grepmail -E \'$email =~ /pattern/\' no_such_file' =>
    { 'stderr' => { 'search' => '[No such file or directory]',
      'replace' => No_such_file_or_directory() },
    },
  'grepmail pattern no_such_file' =>
    { 'stderr' => { 'search' => '[No such file or directory]',
      'replace' => No_such_file_or_directory() },
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

  my $modified_stdout = "t/temp/$stdout_file";
  my $modified_stderr = "t/temp/$stderr_file";

  my $real_stdout = "t/results/$stdout_file";
  my $real_stderr = "t/results/$stderr_file";

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
    LocalizeTestOutput($localization->{'stderr'}, $real_stderr, $modified_stderr)
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

