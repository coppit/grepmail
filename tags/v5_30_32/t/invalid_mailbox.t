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

  system "$test 1>$test_stdout 2>$test_stderr";

  if (!$? && defined $error_expected)
  {
    ok(0,"Did not encounter an error executing the test when one was expected.");
    return;
  }

  if ($? && !defined $error_expected)
  {
    ok(0, "Encountered an error executing the test when one was not expected.\n" .
      "See $test_stdout and $test_stderr.");
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

  Do_Diff($test_stdout,$modified_stdout);
  Custom_Do_Diff($modified_stderr_1,$modified_stderr_2,$test_stderr);

  unlink $modified_stdout;
  unlink $modified_stderr_1;
  unlink $modified_stderr_2;
}

# ---------------------------------------------------------------------------

sub Custom_Do_Diff
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
      ok(0,"Couldn't do diff on results.");
      return;
    }

    if ($diff_err ne '')
    {
      ok(0,$diff_err);
      return;
    }

    local $/ = "\n";

    my @diffs = `cat $output_filename.diff`;
    shift @diffs;
    my $numdiffs = ($#diffs + 1) / 2;

    if ($numdiffs == 0)
    {
      ok(1,"Output $output_filename looks good.");
      unlink "$output_filename.diff";
      return;
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
      ok(0,"Couldn't do diff on results.");
      return;
    }

    if ($diff_err ne '')
    {
      ok(0,$diff_err);
      return;
    }

    local $/ = "\n";

    my @diffs = `cat $output_filename.diff`;
    shift @diffs;
    my $numdiffs = ($#diffs + 1) / 2;

    if ($numdiffs == 0)
    {
      ok(1,"Output $output_filename looks good.");
      unlink "$output_filename.diff";
      return;
    }

    if ($numdiffs != 0)
    {
      ok(0,"Failed, with $numdiffs differences.\n" .
        "  See $output_filename and $output_filename.diff.");
      return;
    }
  }
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  use Mail::Mbox::MessageParser;

  unless (defined $Mail::Mbox::MessageParser::Config{'programs'}{'gzip'})
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

