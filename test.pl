#!/usr/bin/perl

# These tests operate on a mail archive I found on the web at
# http://el.www.media.mit.edu/groups/el/projects/handy-board/mailarc.txt
# and then broke into pieces

# The tested version of grepmail is assumed to be in the current directory.
# Any differences between the expected (timeresults/test#.real) and actual
# (timeresults/test#.out) outputs are stored in test#.diff in the current
# directory.

@timedtests = (
'grepmail library t/big-1.txt t/big-2.txt t/big-3.txt t/big-4.txt',
'grepmail library -d "before oct 15 1998" t/big-1.txt t/big-2.txt t/big-3.txt t/big-4.txt',
'grepmail library t/big-3.txt.gz t/big-3.txt.bz2',
'grepmail -M library t/big-1.txt t/big-2.txt t/big-3.txt t/big-4.txt',
'grepmail -h library t/big-1.txt t/big-2.txt t/big-3.txt t/big-3.txt.gz',
'grepmail -b library t/big-1.txt t/big-2.txt t/big-3.txt t/big-3.txt.bz2',
'grepmail -bh library t/big-1.txt t/big-2.txt t/big-3.txt t/big-3.txt.tz',
'grepmail -h library -d "before oct 15 1998" t/big-1.txt t/big-2.txt t/big-4.txt t/big-3.txt.gz',
'grepmail -b library -d "before oct 15 1998" t/big-1.txt t/big-2.txt t/big-4.txt t/big-3.txt.gz',
'cat t/big-1.txt t/big-2.txt t/big-3.txt t/big-4.txt | grepmail -b hello -d "before oct 15 1998"',
);

use Benchmark qw( timesum timestr timethis );
DoTimeTests();

################################################################################

sub DoTimeTests()
{
  print "Now doing timed tests...\n";

  print "--------------------------------------\n";

  my $old_time;
  my $new_time;

  my $firstTest = 1;
  foreach $test (@timedtests)
  {
    if ($firstTest)
    {
      $firstTest = 0;
    }
    else
    {
      print "--------------------------------------\n";
    }

    print "$test\n";

    local $" = " -I";
    my $includes = "-I@INC";

    $test =~ s/\bgrepmail /$^X $includes \.\/grepmail.old /;

    $result = timethis(4,sub {system "$test > /dev/null"},'OLD');

    if (defined $old_time)
    {
      $old_time = timesum($old_time,$result);
    }
    else
    {
      $old_time = $result;
    }

    if ($?)
    {
      print STDERR "Test failed. Here's the command:\n$test\n";
      exit(1);
    }

    $test =~ s/\bgrepmail.old /grepmail /;

    $result = timethis(4,sub {system "$test >/dev/null"},'NEW');

    if (defined $new_time)
    {
      $new_time = timesum($new_time,$result);
    }
    else
    {
      $new_time = $result;
    }

    if ($?)
    {
      print STDERR "Test failed. Here's the command:\n$test\n";
      exit(1);
    }
  }

  print "======================================\n";

  print "Total time for old version:\n            " .
    timestr($old_time) . "\n";
  print "Total time for new version:\n            " .
    timestr($new_time) . "\n";
}
