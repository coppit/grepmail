#!/usr/bin/perl

# These tests operate on a mail archive I found on the web at
# http://el.www.media.mit.edu/groups/el/projects/handy-board/mailarc.txt
# and then broke into pieces

use strict;
use warnings 'all';

use lib 'lib';
use Benchmark;
use Benchmark::Timer;
use FileHandle;
use Test::ConfigureGrepmail;
use File::Copy;

my $MAILBOX_SIZE = 10_000_000;
my $TEMP_MAILBOX = 't/temp/bigmailbox.txt';

my @IMPLEMENTATIONS_TO_TEST = (
'Perl',
'Grep',
'Cache Init',
'Cache Use',
);

my %TESTS = (
'SIMPLE' => "grepmail library $TEMP_MAILBOX",
#'DATE' => "grepmail library -d \"before oct 15 1998\" $TEMP_MAILBOX",
'COMPRESSED' => "grepmail library $TEMP_MAILBOX.gz",
#'HEADER' => "grepmail -h library $TEMP_MAILBOX",
#'BODY' => "grepmail -b library $TEMP_MAILBOX",
#'BODY & HEADER' => "grepmail -bh library $TEMP_MAILBOX",
#'PIPE' => "cat $TEMP_MAILBOX | grepmail library",
);

mkdir 't/temp';

CreateInputFiles($TEMP_MAILBOX);

foreach my $label (keys %TESTS)
{
  print "\n";

  print "Executing speed test \"$label\":\n$TESTS{$label}\n\n";

  my $mailbox = $TEMP_MAILBOX;
  $mailbox .= '.gz' if $label =~ /COMPRESS/;

  my $data = CollectData($mailbox, $TESTS{$label});

  print "=========================================\n";

  DoHeadToHeadComparison($data);

  print "=========================================\n";

  DoImplementationsComparison($data);

  print "#########################################\n";
}

# make clean will take care of it
#END
#{
#  RemoveInputFile($TEMP_MAILBOX);
#}

################################################################################

sub RemoveInputFile
{
  my $filename = shift;

  unlink $filename;
}

################################################################################

sub CreateInputFiles
{
  my $filename = shift;

  my @mailboxes;

  unless(-e $filename && abs((-s $filename) - $MAILBOX_SIZE) <= $MAILBOX_SIZE*.1)
  {
    print "Making input file ($MAILBOX_SIZE bytes).\n";

    open FILE, 't/mailboxes/mailarc-1.txt';
    local $/ = undef;
    my $data = <FILE>;
    close FILE;

    open FILE, ">$filename";
    binmode FILE;

    my $number = 0;

    while (-s $filename < $MAILBOX_SIZE)
    {
      print FILE $data, "\n";

      $number++;

      # Also make an email with a 1MB attachment.
      print FILE<<"EOF";
From XXXXXXXX\@XXXXXXX.XXX.XXX.XXX Sat Apr 19 19:30:45 2003
Received: from XXXXXX.XXX.XXX.XXX (XXXXXX.XXX.XXX.XXX [##.##.#.##]) by XXX.XXXXXXXX.XXX id h3JNTvkA009295 envelope-from XXXXXXXX\@XXXXXXX.XXX.XXX.XXX for <XXXXX XXXXXX.XXX>; Sat, 19 Apr 2003 19:29:57 -0400 (EDT)8f/81N9n7q
        (envelope-from XXXXXXXX\@XXXXXXX.XXX.XXX.XXX)
Date: Sat, 19 Apr 2003 19:29:50 -0400 (EDT)
From: Xxxxxxx Xxxxxxxx <xxxxxxxx\@xxxxxx.xxx.xxx.xxx>
To: "'Xxxxx Xxxxxx'" <xxxxx\@xxxxxx.xxx>
Subject: RE: FW: Xxxxxx--xxxxxx xxxxxxxx xxxxx xxxxxxx (xxx)
Message-ID: <Pine.LNX.4.44.0304191837520.30945-$number\@xxxxxxx.xxx.xxx.xxx>
MIME-Version: 1.0
Content-Type: MULTIPART/MIXED; BOUNDARY="873612032-418625252-1050794990=:31078"

  This message is in MIME format.  The first part should be readable text,
  while the remaining parts are likely unreadable without MIME-aware tools.
  Send mail to mime\@docserver.cac.washington.edu for more info.

--873612032-418625252-1050794990=:31078
Content-Type: TEXT/PLAIN; charset=US-ASCII

I am not sure if the message below went through.  I accidentally
attached too big a file with it.  Now it's nicely zipped.

--873612032-418625252-1050794990=:31078
Content-Type: APPLICATION/x-gzip; name="testera_dft_4_mchaff.tar.gz"
Content-Transfer-Encoding: BASE64
Content-ID: <Pine.LNX.4.44.0304191929500.3$number\@xxxxxxx.xxx.xxx.xxx>
Content-Description:
Content-Disposition: attachment; filename="foo.tar.gz"

EOF

      print FILE (('x' x 74 . "\n" ) x (1_000_000 / 74));

      print FILE "--873612032-418625252-1050794990=:31078--\n\n";
    }

    close FILE;
  }

  unlink "$filename.gz" if -e "$filename.gz";

  print "Making compressed input file.\n";

  system "gzip -c --force --best $filename > $filename.gz";

  return ($filename, "$filename.gz");
}

################################################################################

sub CollectData
{
  my $filename = shift;
  my $test = shift;

  print "Collecting data...\n\n";

  my %data;

  use IPC::Open3;
  use Symbol qw(gensym);
  open(NULL, ">", File::Spec->devnull);

  # To prevent a "used only once" warning
  my $foo = *NULL;

  copy('grepmail', 't/temp/grepmail');
  copy('grepmail.old', 't/temp/grepmail.old');

  my %settings =
  (
    'Perl' => [0,0],
    'Grep' => [0,1],
    'Cache Init' => [1,1],
    'Cache Use' => [1,0],
  );

  foreach my $old_or_new qw(New Old)
  {
    my $grepmail = 't/temp/grepmail';
    $grepmail .= '.old' if $old_or_new eq 'Old';

    Test::ConfigureGrepmail::Set_Cache_File($grepmail, 't/temp/cache');

    foreach my $impl (@IMPLEMENTATIONS_TO_TEST)
    {
      my $label = "$old_or_new $impl";

      my $new_test = $test;
      $new_test =~ s/\bgrepmail\b/$^X $grepmail/g;

      Test::ConfigureGrepmail::Set_Caching_And_Grep($grepmail,
        @{$settings{$impl}});

      my $t = new Benchmark::Timer(skip => 1, confidence => 97.5, error => 2);

      # Need enough for the statistics to be valid
      my $count = 0;
      while ($count - 1 < 10 || $t->need_more_samples($label))
      {
        unlink 't/temp/cache' if $impl eq 'Cache Init';

        $t->start($label);
        my $pid = open3(gensym, ">&NULL", ">&STDERR", $new_test);
        waitpid($pid, 0);
        $t->stop($label);

        $count++;
      }

      $t->report($label);

      # Fake a benchmark object so we can compare later using Benchmark
      $data{$label} = new Benchmark;
      $data{$label}[5] = 1;
      $data{$label}[1] = $t->result($label);
      $data{$label}[2] = 0;
    }
  }

  close NULL;

  return \%data;
}

################################################################################

sub DoHeadToHeadComparison
{
  my $data = shift;

  print "HEAD TO HEAD COMPARISON\n\n";

  my @labels = grep { s/New // } keys %$data;

  my $first = 1;

  foreach my $label (@labels)
  {
    next unless exists $data->{"Old $label"} && exists $data->{"New $label"};

    print "-----------------------------------------\n"
      unless $first;

    my %head_to_head = ("Old $label" => $data->{"Old $label"},
      "New $label" => $data->{"New $label"});
    Benchmark::cmpthese(\%head_to_head);

    $first = 0;
  }
}

################################################################################

sub DoImplementationsComparison
{
  my $data = shift;

  print "IMPLEMENTATION COMPARISON\n\n";

  {
    my @old_labels = grep { /Old / } keys %$data;

    my %old;
    
    foreach my $label (@old_labels)
    {
      $old{$label} = $data->{$label};
    }

    Benchmark::cmpthese(\%old);
  }

  print "-----------------------------------------\n";

  {
    my @new_labels = grep { /New / } keys %$data;

    my %new;
    
    foreach my $label (@new_labels)
    {
      $new{$label} = $data->{$label};
    }

    Benchmark::cmpthese(\%new);
  }
}

################################################################################
