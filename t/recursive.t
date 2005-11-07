#!/usr/bin/perl

use strict;

use Test::More;
use lib 't';
use Test::Utils;
use File::Spec::Functions qw( :ALL );
use ExtUtils::Command;
use Cwd;

my %tests = (
'grepmail -Rq Handy t/temp/directory'
  => ['recursive','none'],
"grepmail -Rq -E $single_quote\$email =~ /Handy/$single_quote t/temp/directory"
  => ['recursive','none'],
'grepmail -Lq Handy t/temp/directory_with_links'
  => ['recursive2','none'],
);

my %expected_errors = (
);

mkdir 't/temp', 0700;

# Copy over the files so that there are no version control directories in our
# search directory. I could use File::Copy, but it doesn't support globbing
# and multiple-file copying. :(
{
  my @old_argv = @ARGV;
  mkdir 't/temp/directory', 0700;
  @ARGV = ('t/mailboxes/directory/*txt*', 't/temp/directory');
  cp();
  mkdir 't/temp/directory_with_links', 0700;
  @ARGV = ('t/mailboxes/directory/*txt*', 't/temp/directory_with_links');
  cp();

  # Ignore the failed links. We'll let SetSkip deal with the test cases for
  # systems that don't support it.
  eval {
    symlink(cwd() . "/t/temp/directory",
      't/temp/directory_with_links/symlink');
    link(cwd() . "/t/temp/directory",
      't/temp/directory_with_links/link');
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


  my $real_stdout = catfile('t','results',$stdout_file);
  my $real_stderr = catfile('t','results',$stderr_file);

  Do_Diff($test_stdout,$real_stdout);
  Do_Diff($test_stderr,$real_stderr);
}

# ---------------------------------------------------------------------------

sub SetSkip
{
  my %tests = %{ shift @_ };

  my %skip;

  unless ( eval { symlink("",""); 1 } && eval { link("",""); 1} ) {
    $skip{'grepmail -Rq Handy t/temp/directory_with_links'} =
      'Links or symbolic links are not supported on this platform';
  }

  return %skip;
}

# ---------------------------------------------------------------------------

