#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
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

  SKIP:
  {
    skip("$skip{$test}",1) if exists $skip{$test};

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
  my $modified_stderr_1 = "t/temp/${stderr_file}_1";
  my $modified_stderr_2 = "t/temp/${stderr_file}_2";

  my $real_stdout = catfile('t','results',$stdout_file);
  my $real_stderr = catfile('t','results',$stderr_file);

  if (defined $localization->{'stdout'})
  {
    LocalizeTestOutput($localization->{'stdout'}, $real_stdout, $modified_stdout,0);
  }
  else
  {
    copy($real_stdout, $modified_stdout);
  }

  if (defined $localization->{'stderr'})
  {
    LocalizeTestOutput($localization->{'stderr'}, $real_stderr, $modified_stderr_1,0);
    LocalizeTestOutput($localization->{'stderr'}, $real_stderr, $modified_stderr_2,1);
  }
  else
  {
    copy($real_stderr, $modified_stderr_1);
    copy($real_stderr, $modified_stderr_2);
  }

  CustomCheckDiffs([$modified_stdout,$test_stdout],[$modified_stderr_1,$modified_stderr_2,$test_stderr]);

  unlink $modified_stdout;
  unlink $modified_stderr_1;
  unlink $modified_stderr_2;
}

# ---------------------------------------------------------------------------

sub CustomCheckDiffs
{
  my @pairs = @_;

  foreach my $pair (@pairs)
  {
    if (@$pair == 2)
    {
      my $filename = $pair->[0];
      my $output_filename = $pair->[1];

      my ($diff,$result) = DoDiff($filename,$output_filename);

      ok(0), return if $diff == 0;
      ok(0), return if $result == 0;
    }
    # Compare two versions of the file. Either can match for success
    elsif (@$pair == 3)
    {
      my $filename_1 = $pair->[0];
      my $filename_2 = $pair->[1];
      my $output_filename = $pair->[2];

      my ($diff,$result) = CustomDoDiff($filename_1,$filename_2,$output_filename);

      ok(0), return if $diff == 0;
      ok(0), return if defined $result && $result == 0;
    }
    else
    {
      die "Incorrect files to check differences\n";
    }
  }

  ok(1), return;
}

# ---------------------------------------------------------------------------

sub CustomDoDiff
{
  my $filename_1 = shift;
  my $filename_2 = shift;
  my $output_filename = shift;

  {
    my $diffstring = "diff $output_filename $filename_1";

    system "echo $diffstring > $output_filename.diff ".
      "2>$output_filename.diff.error";

    system "$diffstring >> $output_filename.diff ".
      "2>$output_filename.diff.error";

    open DIFF_ERR, "$output_filename.diff.error";
    my $diff_err = join '', <DIFF_ERR>;
    close DIFF_ERR;

    unlink "$output_filename.diff.error";

    if ($? == 2)
    {
      print "Couldn't do diff on results.\n";
      return (0,undef);
    }

    if ($diff_err ne '')
    {
      print $diff_err;
      return (0,undef);
    }

    local $/ = "\n";

    my @diffs = `cat $output_filename.diff`;
    shift @diffs;
    my $numdiffs = ($#diffs + 1) / 2;

    if ($numdiffs == 0)
    {
      print "Output $output_filename looks good.\n";

      unlink "$output_filename.diff";
      return (1,1);
    }

    if ($numdiffs != 0)
    {
      print "First try resulted in $numdiffs differences. Trying other order.\n";
    }
  }

  {
    my $diffstring = "diff $output_filename $filename_2";

    system "echo $diffstring > $output_filename.diff ".
      "2>$output_filename.diff.error";

    system "$diffstring >> $output_filename.diff ".
      "2>$output_filename.diff.error";

    open DIFF_ERR, "$output_filename.diff.error";
    my $diff_err = join '', <DIFF_ERR>;
    close DIFF_ERR;

    unlink "$output_filename.diff.error";

    if ($? == 2)
    {
      print "Couldn't do diff on results.\n";
      return (0,undef);
    }

    if ($diff_err ne '')
    {
      print $diff_err;
      return (0,undef);
    }

    local $/ = "\n";

    my @diffs = `cat $output_filename.diff`;
    shift @diffs;
    my $numdiffs = ($#diffs + 1) / 2;

    if ($numdiffs == 0)
    {
      print "Output $output_filename looks good.\n";

      unlink "$output_filename.diff";
      return (1,1);
    }

    if ($numdiffs != 0)
    {
      print "Failed, with $numdiffs differences.\n";
      print "  See $output_filename and " .
        "$output_filename.diff.\n";
      return (1,0);
    }
  }
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
  my $flip = shift;

  open REAL, $original_file or die $!;
  local $/ = undef;
  my $original = <REAL>;
  close REAL;

  my $new = $original;

  $new =~ s/(\[Broken Pipe\]\r?\n)(.*)/$2$1/s if $flip;

  $new =~ s/\Q$search_replace->{'search'}\E/$search_replace->{'replace'}/gx;

  $search_replace->{'search'} =~ s/\n/\r\n/g;
  $new =~ s/\Q$search_replace->{'search'}\E/$search_replace->{'replace'}/gx;

  open REAL, ">$new_file";
  binmode REAL;
  print REAL $new;
  close REAL;
}

# ---------------------------------------------------------------------------

