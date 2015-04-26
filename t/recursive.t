#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );
use ExtUtils::Command;

my %tests = (
"grepmail -Rq Handy $TEMPDIR/directory"
  => ['recursive','none'],
"grepmail -Rq -E $single_quote\$email =~ /Handy/$single_quote $TEMPDIR/directory"
  => ['recursive','none'],
"grepmail -Lq Handy $TEMPDIR/directory_with_links"
  => ['recursive2','none'],
"grepmail -Rq Handy $TEMPDIR/directory_with_links"
  => ['recursive','none'],
);

my %expected_errors = (
);

# Copy over the files so that there are no version control directories in our
# search directory. I could use File::Copy, but it doesn't support globbing
# and multiple-file copying. :(
{
  my @old_argv = @ARGV;
  mkdir "$TEMPDIR/directory", 0700;
  @ARGV = ('t/mailboxes/directory/*txt*', "$TEMPDIR/directory");
  cp();
  mkdir "$TEMPDIR/directory_with_links", 0700;

  # Ignore the failed links. We'll let SetSkip deal with the test cases for
  # systems that don't support it.
  eval {
    symlink("$TEMPDIR/directory", "$TEMPDIR/directory_with_links/symlink");
    mkdir "$TEMPDIR/directory_with_links/subdir", 0700;
    link("$TEMPDIR/directory/mailarc-2.txt", "$TEMPDIR/directory_with_links/subdir/link.txt");
  };
  @ARGV = @old_argv;
}

plan tests => scalar (keys %tests) * 2;

my %skip = SetSkip(\%tests);

foreach my $test (sort keys %tests) 
{
  print "Running test:\n  $test\n";

  SKIP:
  {
    skip("$skip{$test}",2) if exists $skip{$test};

    TestIt($test, $tests{$test}, $expected_errors{$test});
  }
}

# ---------------------------------------------------------------------------

sub TestIt
{
  my $test = shift;
  my ($stdout_file,$stderr_file) = @{ shift @_ };
  my $error_expected = shift;

  my $testname = [splitdir($0)]->[-1];
  $testname =~ s#\.t##;

  my $perl = perl_with_inc();

  $test =~ s#\bgrepmail\s#$perl blib/script/grepmail -C $TEMPDIR/cache #g;

  my $test_stdout = catfile($TEMPDIR,"${testname}_$stdout_file.stdout");
  my $test_stderr = catfile($TEMPDIR,"${testname}_$stderr_file.stderr");

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

  my $real_stdout = catfile('t','results',$stdout_file);
  my $real_stderr = catfile('t','results',$stderr_file);

  # Compare STDERR first on the assumption that if STDOUT is different, STDERR
  # is too and contains something useful.
  Do_Diff($test_stderr,$real_stderr);
  Do_Diff($test_stdout,$real_stdout);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  unless ( eval { symlink("",""); 1 } && eval { link("",""); 1} ) {
    $skip{"grepmail -Rq Handy $TEMPDIR/directory_with_links"} =
      'Links or symbolic links are not supported on this platform';
  }

  return %skip;
}

# ---------------------------------------------------------------------------

