#!/usr/bin/perl

# These tests operate on a mail archive I found on the web at
# http://el.www.media.mit.edu/groups/el/projects/handy-board/mailarc.txt
# and then broke into pieces

# You must have bzip2 and gunzip installed for all the tests to work.

# The tested version of grepmail is assumed to be in the current directory.
# Any differences between the expected (t/results/test#.real) and actual
# (t/results/test#.out) outputs are stored in test#.diff in the current
# directory.

# The $testNumber is the test number from Test::Harness' point of view. It
# starts at 1 and goes up to the number of test cases ($#tests + 1) times the
# number of implementations to test. The $testID is the index into @tests, and
# is equal to ($testNumber - 1) % ($#tests + 1).

use strict;
use Test;

my @tests = (
'grepmail library -d "before July 9 1998" t/mailarc-1.txt',
'grepmail -v "(library|job)" t/mailarc-1.txt',
'grepmail -b mime t/mailarc-1.txt',
'grepmail -h Wallace t/mailarc-1.txt',
'grepmail -h "^From.*aarone" t/mailarc-1.txt',
'grepmail -br library t/mailarc-1.txt t/mailarc-2.txt',
'grepmail -hb library t/mailarc-1.txt',
'grepmail -b library t/mailarc-1.txt',
'grepmail -h library t/mailarc-1.txt',
'grepmail library t/mailarc-1.txt',
'grepmail -hbv library t/mailarc-1.txt',
'grepmail -bv library t/mailarc-1.txt',
'grepmail -hv library t/mailarc-1.txt',
'grepmail -v library t/mailarc-1.txt',
'cat t/mailarc-1.txt | grepmail -v library',
'cat t/mailarc-2.txt.gz | grepmail -v library',
'grepmail -v library t/mailarc-2.txt.gz',
'grepmail -l library t/mailarc-1.txt t/mailarc-2.txt',
'grepmail -e library t/mailarc-1.txt',
'grepmail -e library -l t/mailarc-1.txt t/mailarc-2.txt',
'cat t/mailarc-2.txt.bz2 | grepmail -v library',
'grepmail -v library t/mailarc-2.txt.bz2',
'grepmail -d "before July 15 1998" t/mailarc-1.txt',
'grepmail library t/mailarc-2.txt.gz t/mailarc-1.txt',
'grepmail --help',
'cat t/mailarc-2.txt.tz | grepmail library',
'grepmail library no_such_file',
'cat no_such_file 2>/dev/null | grepmail library',
'grepmail -d "after armageddon" library t/mailarc-1.txt',
'grepmail library -s 2000 t/mailarc-1.txt',
'grepmail library -u t/mailarc-1.txt',
'grepmail -u t/mailarc-1.txt',
'grepmail -bi imagecraft -u t/mailarc-1.txt',
'grepmail -d "before 1st Tuesday in July 1998" t/mailarc-1.txt',
'grepmail -d "before 7/15/1998" t/mailarc-2.txt',
'grepmail -d "" t/mailarc-2.txt',
'grepmail -ad "before 7/15/1998" t/mailarc-1.txt',
'grepmail -n library t/mailarc-1.txt',
'grepmail -n library t/mailarc-1.txt t/mailarc-2.txt',
'grepmail "From.*luikeith@egr.msu.edu" t/mailarc-1.txt',
'grepmail -m library t/mailarc-1.txt t/mailarc-2.txt',
'grepmail -mn library t/mailarc-1.txt t/mailarc-2.txt',
'grepmail . t/gnus.txt',
);

# Tests for certain supported options.
my @date_manip = (33);
my @bzip2 = (20,21);
my @gzip = (15,16,17,19,23);
my @tzip = (25);
my @error_cases = (26,27,28);

# Tests that need language localization
my %localization = (
  27 => { 'stderr' => { 'search' => 'No such file or directory',
                        'replace' => No_such_file_or_directory() },
        },
);

my $version = GetVersion();

my $bzip2 = 0;
my $gzip = 0;
my $tzip = 0;
my $date_manip = 0;
my $mail_folder_fastreader = 0;

{
  my $temp;

  # Save old STDERR and redirect temporarily to nothing. This will prevent the
  # test script from emitting a warning if the backticks can't find the
  # compression programs
  use vars qw(*OLDSTDERR);
  open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
  open STDERR,">/dev/null" or die "Can't redirect STDERR to /dev/null: $!\n";

  $temp = `bzip2 -h 2>&1`;
  $bzip2 = 1 if $temp =~ /usage/;

  $temp = `gzip -h 2>&1`;
  $gzip = 1 if $temp =~ /usage/;

  $temp = `tzip -h 2>&1`;
  $tzip = 1 if $temp =~ /usage/;

  open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

  if (ModuleInstalled("Date::Manip"))
  {
    Check_Known_Timezone();
    $date_manip = 1;
  }
  else
  {
    $date_manip = 0;
  }

  if (ModuleInstalled("Mail::Folder::FastReader"))
  {
    $mail_folder_fastreader = 1;
  }
  else
  {
    $mail_folder_fastreader = 0;
  }
}

if ($mail_folder_fastreader)
{
  plan (tests => ($#tests + 1) * 2);
}
else
{
  plan (tests => $#tests + 1);
}

print "Testing $version version of grepmail.\n\n";

if ($mail_folder_fastreader)
{
  print "Testing Mail::Folder::FastReader-based folder reader implementation.\n\n";

  DoTests($ARGV[0],1);
}

print "Testing perl-based folder reader implementation.\n\n";

DoTests($ARGV[0],0);

# ---------------------------------------------------------------------------

sub Check_Known_Timezone
{
  require Date::Manip;

  unless (eval 'Date::Manip::Date_TimeZone()')
  {
    print <<EOF;

WARNING: Your time zone is not recognized by Date::Manip. It is likely
that many test cases related to dates will fail. See the README for more
information on how to resolve this problem.

EOF
  }
}

# ---------------------------------------------------------------------------

sub GetVersion
{
  open CODE, "blib/script/grepmail" or die "Can't open grepmail script: $!\n";
  my $code = join '',<CODE>;
  close CODE;

  return 'Date::Manip' if $code =~ /require Date::Manip/s;
  return 'Date::Parse' if $code =~ /require Date::Parse/s;
}

# ---------------------------------------------------------------------------

sub CheckSkip
{
  my $testID = shift;

  if((grep {$_ == $testID} @date_manip) && !$date_manip)
  {
    print "Skipping test for Date::Manip version\n";
    skip(1,1);
    return 1;
  }

  if((grep {$_ == $testID} @bzip2) && !$bzip2)
  {
    print "Skipping test using bzip2\n";
    skip(1,1);
    return 1;
  }

  if((grep {$_ == $testID} @gzip) && !$gzip)
  {
    print "Skipping test using gzip\n";
    skip(1,1);
    return 1;
  }

  if((grep {$_ == $testID} @tzip) && !$tzip)
  {
    print "Skipping test using tzip\n";
    skip(1,1);
    return 1;
  }

  return 0;
}

# ---------------------------------------------------------------------------

sub LocalizeTestOutput
{
  my $testID = shift;

  $testID++;

  return unless exists $localization{$testID};

  if (exists $localization{$testID}{'stdout'})
  {
    open REAL, "t/results/test$testID.stdout.real";
    local $/ = undef;
    my $output = <REAL>;
    close REAL;

    my $replaced = $output;

    $replaced =~ s/\Q$localization{$testID}{'stdout'}{'search'}\E/
                     $localization{$testID}{'stdout'}{'replace'}/gx;

    if ($output ne $replaced)
    {
      open REAL, ">t/results/test$testID.stdout.real";
      print REAL $replaced;
      close REAL;
    }
  }

  if (exists $localization{$testID}{'stderr'})
  {
    open REAL, "t/results/test$testID.stderr.real";
    local $/ = undef;
    my $output = <REAL>;
    close REAL;

    my $replaced = $output;

    $replaced =~ s/\Q$localization{$testID}{'stderr'}{'search'}\E/$localization{$testID}{'stderr'}{'replace'}/gx;

    if ($output ne $replaced)
    {
      open REAL, ">t/results/test$testID.stderr.real";
      print REAL $replaced;
      close REAL;
    }
  }
}

# ---------------------------------------------------------------------------

sub ModuleInstalled
{
  my $module_name = shift;

  $module_name =~ s/::/\//g;
  $module_name .= '.pm';

  foreach my $inc (@INC)
  {
    return 1 if -e "$inc/$module_name";
  }

  return 0;
}

# ---------------------------------------------------------------------------

my $testNumber;

sub DoTests
{
  my $test_constraint = shift;
  my $mail_folder_fastreader = shift;

  $testNumber = 1 unless defined $testNumber;

  my $testID = ($testNumber - 1) % ($#tests+1);

  while (1)
  {
    my $test = $tests[$testID];
    if (defined $test_constraint)
    {
      next if ($test_constraint =~ /^\d+$/ && $testNumber != $test_constraint);
      next if ($test_constraint =~ /^(\d+)-$/ && $testNumber < $1);
      next if ($test_constraint =~ /^(\d+)-(\d+)$/ &&
        ($testNumber < $1 || $testNumber > $2));
    }

    local $" = " -I";
    my $includes = "-I@INC";

    $test =~ s#grepmail#$^X $includes blib/script/grepmail#sg;
    $test =~ s#grepmail#grepmail -Z#sg unless $mail_folder_fastreader;

    print "$test\n";

    if (CheckSkip($testID))
    {
      print "\n";
      next;
    }

    LocalizeTestOutput($testID);

    system "$test 1>t/results/test$testNumber.stdout " .
      "2>t/results/test$testNumber.stderr";

    if ($? && (!grep {$_ == $testID} @error_cases))
    {
      print "Error executing test.\n\n";
      ok(0);
      next;
    }

    CheckDiffs($testNumber,$testID+1);
    print "\n";
  }
  continue
  {
    $testNumber++;
    return if $testID == $#tests;
    $testID = ($testNumber - 1) % ($#tests + 1);
  }
}

# ---------------------------------------------------------------------------

sub CheckDiffs
{
  my $testNumber = shift;
  my $testID1 = shift;

  my ($stdout_diff,$stdout_result) = DoDiff($testNumber,$testID1,'stdout');
  my ($stderr_diff,$stderr_result) = DoDiff($testNumber,$testID1,'stderr');

  ok(0), return if $stdout_diff == 0 || $stderr_diff == 0;
  ok(0), return if $stdout_result == 0 || $stderr_result == 0;
  ok(1), return;
}

# ---------------------------------------------------------------------------

# Returns the results of the diff, and the results of the test.

sub DoDiff
{
  my $testNumber = shift;
  my $testID = shift;
  my $resultType = shift;

  my $diffstring = "diff t/results/test$testNumber.$resultType " .
    "t/results/test$testID.$resultType.real";

  system "echo $diffstring > t/results/test$testNumber.$resultType.diff ".
    "2>t/results/test$testNumber.$resultType.diff.error";

  system "$diffstring >> t/results/test$testNumber.$resultType.diff ".
    "2>t/results/test$testNumber.$resultType.diff.error";

  open DIFF_ERR, "t/results/test$testNumber.$resultType.diff.error";
  my $diff_err = join '', <DIFF_ERR>;
  close DIFF_ERR;

  unlink "t/results/test$testNumber.$resultType.diff.error";

  if ($? == 2)
  {
    print "Couldn't do diff on \U$resultType\E results.\n";
    return (0,undef);
  }

  if ($diff_err ne '')
  {
    print $diff_err;
    return (0,undef);
  }

  my @diffs = `cat t/results/test$testNumber.$resultType.diff`;
  shift @diffs;
  my $numdiffs = ($#diffs + 1) / 2;

  if ($numdiffs != 0)
  {
    print "Failed, with $numdiffs differences in \U$resultType\E.\n";
    print "  See t/results/test$testNumber.$resultType and " .
      "t/results/test$testNumber.$resultType.diff.\n";
    return (1,0);
  }

  if ($numdiffs == 0)
  {
    print "\U$resultType\E looks good.\n";

    unlink "t/results/test$testNumber.$resultType";
    unlink "t/results/test$testNumber.$resultType.diff";
    return (1,1);
  }
}

# ---------------------------------------------------------------------------

use vars qw( *FOO );

sub No_such_file_or_directory
{
  my $filename;

  $filename = 0;

  $filename++ while -e $filename;

  local $!;

  open FOO, $filename;

  die q{Couldn't determine local text for "No such file or directory"}
    if $! eq '';

  return $!;
}
