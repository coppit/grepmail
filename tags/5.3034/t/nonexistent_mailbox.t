#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );
use File::Copy;

my %tests = (
'grepmail pattern no_such_file'
  => ['none','no_such_file'],
"$^X -MExtUtils::Command -e cat no_such_file 2>" . devnull() .
  " | grepmail pattern"
  => ['none','no_data'],
"grepmail -E $single_quote\$email =~ /pattern/$single_quote no_such_file"
  => ['none','no_such_file'],
"$^X -MExtUtils::Command -e cat no_such_file 2>" . devnull() .
  " | grepmail -E $single_quote\$email =~ /pattern/$single_quote"
  => ['none','no_data'],
);

my %expected_errors = (
"$^X -MExtUtils::Command -e cat no_such_file 2>" . devnull() .
  " | grepmail pattern"
  => 1,
"$^X -MExtUtils::Command -e cat no_such_file 2>" . devnull() .
  " | grepmail -E $single_quote\$email =~ /pattern/$single_quote"
  => 1,
);

my %localization = (
  "grepmail -E $single_quote\$email =~ /pattern/$single_quote no_such_file" =>
    { 'stderr' => { 'search' => '[No such file or directory]',
      'replace' => No_such_file_or_directory() },
    },
  'grepmail pattern no_such_file' =>
    { 'stderr' => { 'search' => '[No such file or directory]',
      'replace' => No_such_file_or_directory() },
    },
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

    TestIt($test, $tests{$test}, $expected_errors{$test}, $localization{$test});
  }
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

  print "$test 1>$test_stdout 2>$test_stderr\n";
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
    LocalizeTestOutput($localization->{'stderr'}, $real_stderr, $modified_stderr)
  }
  else
  {
    copy($real_stderr, $modified_stderr);
  }

  Do_Diff($test_stdout,$modified_stdout);
  Do_Diff($test_stderr,$modified_stderr);

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

