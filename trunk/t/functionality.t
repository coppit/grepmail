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
use lib 'lib';
use Test::CompareFiles;

mkdir 't/temp';

my @tests = (
# 1
'grepmail library -d "before July 9 1998" t/mailboxes/mailarc-1.txt',
# 2
'grepmail -v "(library|job)" t/mailboxes/mailarc-1.txt',
# 3
'grepmail -b mime t/mailboxes/mailarc-1.txt',
# 4
'grepmail -h Wallace t/mailboxes/mailarc-1.txt',
# 5
'grepmail -h "^From.*aarone" t/mailboxes/mailarc-1.txt',
# 6
'grepmail -br library t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 7
'grepmail -hb library t/mailboxes/mailarc-1.txt',
# 8
'grepmail -b library t/mailboxes/mailarc-1.txt',
# 9
'grepmail -h library t/mailboxes/mailarc-1.txt',
# 10
'grepmail library t/mailboxes/mailarc-1.txt',
# 11
'grepmail -hbv library t/mailboxes/mailarc-1.txt',
# 12
'grepmail -bv library t/mailboxes/mailarc-1.txt',
# 13
'grepmail -hv library t/mailboxes/mailarc-1.txt',
# 14
'grepmail -v library t/mailboxes/mailarc-1.txt',
# 15
'cat t/mailboxes/mailarc-1.txt | grepmail -v library',
# 16
'cat t/mailboxes/mailarc-2.txt.gz | grepmail -v library',
# 17
'grepmail -v library t/mailboxes/mailarc-2.txt.gz',
# 18
'grepmail -l library t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 19
'grepmail -e library t/mailboxes/mailarc-1.txt',
# 20
'grepmail -e library -l t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 21
'cat t/mailboxes/mailarc-2.txt.bz2 | grepmail -v library',
# 22
'grepmail -v library t/mailboxes/mailarc-2.txt.bz2',
# 23
'grepmail -d "before July 15 1998" t/mailboxes/mailarc-1.txt',
# 24
'grepmail library t/mailboxes/mailarc-2.txt.gz t/mailboxes/mailarc-1.txt',
# 25
'grepmail --help',
# 26
'cat t/mailboxes/mailarc-2.txt.tz | grepmail library',
# 27
'grepmail library no_such_file',
# 28
'cat no_such_file 2>/dev/null | grepmail library',
# 29
'grepmail -d "after armageddon" library t/mailboxes/mailarc-1.txt',
# 30
'grepmail library -s \'<=2000\' t/mailboxes/mailarc-1.txt',
# 31
'grepmail library -u t/mailboxes/mailarc-1.txt',
# 32
'grepmail -u t/mailboxes/mailarc-1.txt',
# 33
'grepmail -bi imagecraft -u t/mailboxes/mailarc-1.txt',
# 34
'grepmail -d "before 1st Tuesday in July 1998" t/mailboxes/mailarc-1.txt',
# 35
'grepmail -d "before 7/15/1998" t/mailboxes/mailarc-2.txt',
# 36
'grepmail -d "" t/mailboxes/mailarc-2.txt',
# 37
'grepmail -ad "before 7/15/1998" t/mailboxes/mailarc-1.txt',
# 38
'grepmail -n library t/mailboxes/mailarc-1.txt',
# 39
'grepmail -n library t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 40
'grepmail "From.*luikeith@egr.msu.edu" t/mailboxes/mailarc-1.txt',
# 41
'grepmail -m library t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 42
'grepmail -mn library t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 43
'grepmail test t/mailboxes/gnus.txt',
# 44
'grepmail -ibS Free t/mailboxes/mailarc-1.txt',
# 45
'grepmail Driving t/mailboxes/mailarc-1.txt',
# 46
'grepmail -r . t/mailboxes/mailseparators.txt',
# 47
'grepmail -Rq library t/mailboxes/directory',
# 48
'grepmail -S \'So I got Unix\' t/mailboxes/mailarc-1.txt',
# 49
'grepmail -X \'={75,}\' -S \'61 2 9844 5381\' t/mailboxes/mailarc-1.txt',
# 50
'grepmail -Y \'.*\' Wallace t/mailboxes/mailarc-1.txt',
# 51
'grepmail -Y \'.*\' "^From.*aarone" t/mailboxes/mailarc-1.txt',
# 52
'grepmail -Y \'.*\' -b library t/mailboxes/mailarc-1.txt',
# 53
'grepmail -Y \'.*\' library t/mailboxes/mailarc-1.txt',
# 54
'grepmail -Y \'.*\' -bv library t/mailboxes/mailarc-1.txt',
# 55
'grepmail -Y \'.*\' -v library t/mailboxes/mailarc-1.txt',
# 56
'grepmail -Y \'(^From:|^TO:)\' Edsinger t/mailboxes/mailarc-1.txt',
# 57
'grepmail -Y \'(?i)^x-mailer:\' -i mozilla.4 t/mailboxes/mailarc-1.txt',
# 58
'grepmail -u t/mailboxes/mailarc-3.txt',
# 59
'cat t/mailboxes/non-mailbox.txt.gz | grepmail pattern',

# -E tests, starting with test 60
# 60
'grepmail -E \'$email =~ /library/\' -d "before July 9 1998" t/mailboxes/mailarc-1.txt',
# 61
'grepmail -v -E \'$email =~ /(library|job)/\' t/mailboxes/mailarc-1.txt',
# 62
'grepmail -E \'$email_body =~ /mime/\' t/mailboxes/mailarc-1.txt',
# 63
'grepmail -E \'$email_header =~ /Wallace/\' t/mailboxes/mailarc-1.txt',
# 64
'grepmail -E \'$email_header =~ /^From.*aarone/\' t/mailboxes/mailarc-1.txt',
# 65
'grepmail -r -E \'$email_body =~ /library/\' t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 66
'grepmail -E \'$email_header =~ /library/ && $email_body =~ /library/\' t/mailboxes/mailarc-1.txt',
# 67
'grepmail -E \'$email_body =~ /library/\' t/mailboxes/mailarc-1.txt',
# 68
'grepmail -E \'$email_header =~ /library/\' t/mailboxes/mailarc-1.txt',
# 69
'grepmail -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt',
# 70
'grepmail -v -E \'$email_header =~ /library/ && $email_body =~ /library/\' t/mailboxes/mailarc-1.txt',
# 71
'grepmail -v -E \'$email_body =~ /library/\' t/mailboxes/mailarc-1.txt',
# 72
'grepmail -v -E \'$email_header =~ /library/\' t/mailboxes/mailarc-1.txt',
# 73
'grepmail -v -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt',
# 74
'cat t/mailboxes/mailarc-1.txt | grepmail -v -E \'$email =~ /library/\'',
# 75
'cat t/mailboxes/mailarc-2.txt.gz | grepmail -v -E \'$email =~ /library/\'',
# 76
'grepmail -v -E \'$email =~ /library/\' t/mailboxes/mailarc-2.txt.gz',
# 77
'grepmail -l -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 78
'grepmail -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt',
# 79
'grepmail -E \'$email =~ /library/\' -l t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 80
'cat t/mailboxes/mailarc-2.txt.bz2 | grepmail -v -E \'$email =~ /library/\'',
# 81
'grepmail -v -E \'$email =~ /library/\' t/mailboxes/mailarc-2.txt.bz2',
# 82
'grepmail -E \'$email =~ /library/\' t/mailboxes/mailarc-2.txt.gz t/mailboxes/mailarc-1.txt',
# 83
'cat t/mailboxes/mailarc-2.txt.tz | grepmail -E \'$email =~ /library/\'',
# 84
'grepmail -E \'$email =~ /library/\' no_such_file',
# 85
'cat no_such_file 2>/dev/null | grepmail -E \'$email =~ /library/\'',
# 86
'grepmail -d "after armageddon" -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt',
# 87
'grepmail -E \'$email =~ /library/\' -s \'<=2000\' t/mailboxes/mailarc-1.txt',
# 88
'grepmail -E \'$email =~ /library/\' -u t/mailboxes/mailarc-1.txt',
# 89 Unimplemented
'grepmail -i \'$email_body =~ /imagecraft/mailboxes/\' -u t/mailboxes/mailarc-1.txt',
# 90
'grepmail -n -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt',
# 91
'grepmail -n -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 92
'grepmail -E \'$email =~ /From.*luikeith\@egr.msu.edu/\' t/mailboxes/mailarc-1.txt',
# 93
'grepmail -m -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 94
'grepmail -mn -E \'$email =~ /library/\' t/mailboxes/mailarc-1.txt t/mailboxes/mailarc-2.txt',
# 95 Unimplemented
'grepmail -iS -E \'$email_body =~ /Free/\' t/mailboxes/mailarc-1.txt',
# 96
'grepmail -E \'$email =~ /Driving/\' t/mailboxes/mailarc-1.txt',
# 97
'grepmail -Rq -E \'$email =~ /library/\' t/mailboxes/directory',
# 98 Unimplemented
'grepmail -S \'$email =~ /So I got Unix/\' t/mailboxes/mailarc-1.txt',
# 99 Unimplemented
'grepmail -X \'={75,}\' -S -E \'$email =~ /61 2 9844 5381/\' t/mailboxes/mailarc-1.txt',
# 100 Unimplemented. -E equivalent?
'grepmail -Y \'.*\' Wallace t/mailboxes/mailarc-1.txt',
# 101 Unimplemented. -E equivalent?
'grepmail -Y \'.*\' "^From.*aarone" t/mailboxes/mailarc-1.txt',
# 102 Unimplemented. -E equivalent?
'grepmail -Y \'.*\' -b library t/mailboxes/mailarc-1.txt',
# 103 Unimplemented. -E equivalent?
'grepmail -Y \'.*\' library t/mailboxes/mailarc-1.txt',
# 104 Unimplemented. -E equivalent?
'grepmail -Y \'.*\' -bv library t/mailboxes/mailarc-1.txt',
# 105 Unimplemented. -E equivalent?
'grepmail -Y \'.*\' -v library t/mailboxes/mailarc-1.txt',
# 106 Unimplemented. -E equivalent?
'grepmail -Y \'(^From:|^TO:)\' Edsinger t/mailboxes/mailarc-1.txt',
# 107 Unimplemented. -E equivalent?
'grepmail -Y \'(?i)^x-mailer:\' -i mozilla.4 t/mailboxes/mailarc-1.txt',
# 108
'cat t/mailboxes/non-mailbox.txt.gz | grepmail -E \'$email =~ /pattern/\'',
# 109
'grepmail -E \'$email =~ /library/ && $email =~ /imagecraft/i\' t/mailboxes/mailarc-1.txt',
# 110
'grepmail -E \'$email =~ /library/ && $email_header =~ /Blank/\' t/mailboxes/mailarc-1.txt',
# 111
'grepmail -E \'$email =~ /library/ || $email =~ /Poke/\' t/mailboxes/mailarc-1.txt',
# 112
'grepmail -j ro t/mailboxes/mailarc-1.txt',
# 113
'grepmail -s 1300-1500 t/mailboxes/mailarc-1.txt',
# 114
'grepmail -s \'>3000\' t/mailboxes/mailarc-1.txt',
# 115
'grepmail -s 1211 t/mailboxes/mailarc-1.txt',

# More non -E tests
# 116
'grepmail -f t/patterns t/mailboxes/mailarc-1.txt',

# Test auto-searching for mailboxes
# 117
'MAILDIR=t/mailboxes grepmail library mailarc-1.txt',
# 118
'MAILDIR=t/mailboxes grepmail -d "before July 15 1998" mailarc-1.txt',
);

# Test numbers for certain supported options.
my @date_manip = (34);
my @date_parse = (1, 23, 29, 34, 35, 36, 37, 60, 86);
my @bzip2 = (21,22,80,81);
my @gzip = (16,17,24,59,75,76,82,108);
my @tzip = (26,83);
my @error_cases = (28, 29, 85, 86);
my @unimplemented =
  ( 89, 95, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107);

# Tests that need platform or language localization
my @broken_pipe = (59,108);
my %localization = (
  27 => { 'stderr' => { 'search' => 'No such file or directory',
                        'replace' => No_such_file_or_directory() },
        },
);

my $bzip2 = 0;
my $gzip = 0;
my $tzip = 0;
my $date_manip = 0;
my $date_parse = 0;

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

  if (ModuleInstalled("Date::Parse"))
  {
    $date_parse = 1;
  }
  else
  {
    $date_parse = 0;
  }
}

plan (tests => $#tests + 1);

DoTests($ARGV[0]);

rmdir 't/temp' unless <t/temp/*>;

# ---------------------------------------------------------------------------

sub Check_Known_Timezone
{
  # Date::Manip prior to 5.39 nukes the PATH. Save and restore it to avoid
  # problems.
  my $path = $ENV{PATH};
  require Date::Manip;
  $ENV{PATH} = $path;

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

sub CheckSkip
{
  my $testID = shift;

  if(grep {$_ == $testID+1} @unimplemented)
  {
    print "Skipping test for unimplemented feature\n";
    skip('Skip unimplemented feature',1);
    return 1;
  }

  if((grep {$_ == $testID+1} @date_manip) && !$date_manip)
  {
    print "Skipping test for Date::Manip version\n";
    skip('Skip Date::Manip not available',1);
    return 1;
  }

  if((grep {$_ == $testID+1} @date_parse) && !$date_parse)
  {
    print "Skipping test for Date::Parse\n";
    skip('Skip Date::Parse not available',1);
    return 1;
  }

  if((grep {$_ == $testID+1} @bzip2) && !$bzip2)
  {
    print "Skipping test using bzip2\n";
    skip('Skip bzip2 not available',1);
    return 1;
  }

  if((grep {$_ == $testID+1} @gzip) && !$gzip)
  {
    print "Skipping test using gzip\n";
    skip('Skip gzip not available',1);
    return 1;
  }

  if((grep {$_ == $testID+1} @tzip) && !$tzip)
  {
    print "Skipping test using tzip\n";
    skip('Skip tzip not available',1);
    return 1;
  }

  return 0;
}

# ---------------------------------------------------------------------------

sub HandleBrokenPipe
{
  my $testID = shift;

  $testID++;

  return
    unless scalar(grep { $testID == $_ } @broken_pipe) && $^O eq 'solaris';

  open REAL, "t/results/test$testID.stderr.real";
  local $/ = undef;
  my $output = <REAL>;
  close REAL;

  my $replaced = $output;

  $replaced .= "Broken Pipe\n" unless $output =~ /Broken Pipe/;

  if ($output ne $replaced)
  {
    open REAL, ">t/results/test$testID.stderr.real";
    print REAL $replaced;
    close REAL;
  }
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

    my @newinc;
    foreach my $inc (@INC)
    {
      push (@newinc, split(/ +/,$inc));
    }

    @INC = @newinc;

    {
      local $" = " -I";
      my $includes = "-I@INC";

      $test =~ s#\bgrepmail\s#$^X $includes blib/script/grepmail #sg;
    }

    print "$test\n";

    if (CheckSkip($testID))
    {
      print "\n";
      next;
    }

    HandleBrokenPipe($testID);
    LocalizeTestOutput($testID);

    my $test_stdout_result = "t/temp/test$testNumber.stdout";
    my $test_stderr_result = "t/temp/test$testNumber.stderr";

    system "$test 1>$test_stdout_result 2>$test_stderr_result";

    if (!$? && (grep {$_ == $testID+1} @error_cases))
    {
      print "Did not encounter an error executing the test when one was expected.\n\n";
      ok(0);
      next;
    }

    if ($? && (!grep {$_ == $testID+1} @error_cases))
    {
      print "Encountered an error executing the test when one was not expected.\n\n";
      ok(0);
      next;
    }

    my $real_stdout_result = "t/results/test$testNumber.stdout.real";
    my $real_stderr_result = "t/results/test$testNumber.stderr.real";
    CheckDiffs([$real_stdout_result,$test_stdout_result],
      [$real_stderr_result,$test_stderr_result]);

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
