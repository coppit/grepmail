#!/usr/bin/perl

# These tests operate on a mail archive I found on the web at
# http://el.www.media.mit.edu/groups/el/projects/handy-board/mailarc.txt
# and then broke into pieces

# The tested version of grepmail is assumed to be in the current directory.
# Any differences between the expected (timeresults/test#.real) and actual
# (timeresults/test#.out) outputs are stored in test#.diff in the current
# directory.

$oldGrepmailLocation = "$ENV{HOME}/bin";

@timedtests = (
'grepmail library big-1.txt big-2.txt big-3.txt big-4.txt',
'grepmail library -d "before oct 15 1998" big-1.txt big-2.txt big-3.txt big-4.txt',
'grepmail library big-3.txt.gz big-3.txt.bz2',
'grepmail -h library big-1.txt big-2.txt big-3.txt big-3.txt.gz',
'grepmail -b library big-1.txt big-2.txt big-3.txt big-3.txt.bz2',
'grepmail -bh library big-1.txt big-2.txt big-3.txt big-3.txt.tz',
'grepmail -h library -d "before oct 15 1998" big-1.txt big-2.txt big-4.txt big-3.txt.gz',
'grepmail -b library -d "before oct 15 1998" big-1.txt big-2.txt big-4.txt big-3.txt.gz',
'cat big-1.txt big-2.txt big-3.txt big-4.txt | grepmail -b hello -d "before oct 15 1998"',
);

DoTimeTests();

################################################################################

sub DoTimeTests()
{
print "Now doing timed tests...\n";

unlink "times";

foreach $test (@timedtests)
{
  $test =~ s/grepmail/time $oldGrepmailLocation\/grepmail/;
  print "$test\n";
  system "$test > /dev/null";
  exit if $?;

  $test =~ s/time.*grepmail/time .\/grepmail/;
  print "\n$test\n";
  system "$test > /dev/null";
  exit if $?;

  print "\n";
}
}
