# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

use strict;
$^W = 1;

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..4\n"; }

use Mail::Folder::FastReader qw(reset_line read_email);

my $loaded = 1;

END {print "not ok 1\n" unless $loaded;}

print "ok 1\n";

# ----------------------------------------------------------------------------

my $number_emails;

# ----------------------------------------------------------------------------

# Test that we can open a file and read some emails from a standard file
# handle.

no strict qw(subs);

open EMAIL,"t/mailarc-1.txt" or die $!;

reset_line();
$number_emails = 0;
while(1)
{
  my ($status,$email,$line) = read_email(EMAIL);
  last unless $status;
print substr($email,0,40),"\n";
  $number_emails++ if $status == 1;
}

if ($number_emails == 14)
{
  print "ok 2\n";
}
else
{
  print "not ok 2\n";
  print "number of emails $number_emails != 14\n";
}

close EMAIL;

use strict qw(subs);

# ----------------------------------------------------------------------------

# Test that we can open a file and read some emails from a FileHandle file
# handle.

use FileHandle;

my $EMAIL = new FileHandle;
$EMAIL->open("t/mailarc-1.txt") or die $!;

reset_line();
$number_emails = 0;
while(1)
{
  my ($status,$email,$line) = read_email($EMAIL);
  last unless $status;
  $number_emails++ if $status == 1;
}

if ($number_emails == 14)
{
  print "ok 3\n";
}
else
{
  print "not ok 3\n";
  print "number of emails $number_emails != 14\n";
}

$EMAIL->close();

# ----------------------------------------------------------------------------

# Test that the line number gets reset when a second file handle is read from
# for the first time. We have to do this several times because the OS may not
# happen to give the same file descriptor to the second file handle.

use FileHandle;

my $error = 0;

for (my $i = 0; $i < 10;$i++)
{
  my ($status,$email,$line);

  my $EMAIL1 = new FileHandle;
  reset_line();
  $EMAIL1->open("t/mailarc-1.txt") or die $!;

  ($status,$email,$line) = read_email($EMAIL1);
  ($status,$email,$line) = read_email($EMAIL1);

  $EMAIL1->close();

  my $EMAIL2 = new FileHandle;
  reset_line();
  $EMAIL2->open("t/mailarc-1.txt") or die $!;

  ($status,$email,$line) = read_email($EMAIL2);

  $EMAIL2->close();

  if ($line != 1)
  {
    $error = 1;
    last;
  }
}

if ($error)
{
  print "not ok 4\n";
}
else
{
  print "ok 4\n";
}

# ----------------------------------------------------------------------------
