package Test::CompareFiles;

use strict;
use Exporter;
use Test;

use vars qw( @EXPORT @ISA );

@ISA = qw( Exporter );
@EXPORT = qw( CheckDiffs DoDiff );

sub CheckDiffs
{
  my @pairs = @_;

  foreach my $pair (@pairs)
  {
    my $filename = $pair->[0];
    my $output_filename = $pair->[1];

    my ($diff,$result) = DoDiff($filename,$output_filename);

    ok(0), return if $diff == 0;
    ok(0), return if $result == 0;
  }

  ok(1), return;
}

# ---------------------------------------------------------------------------

# Returns the results of the diff, and the results of the test.

sub DoDiff
{
  my $filename = shift;
  my $output_filename = shift;

  my $diffstring = "diff $output_filename $filename";

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

  if ($numdiffs != 0)
  {
    print "Failed, with $numdiffs differences.\n";
    print "  See $output_filename and " .
      "$output_filename.diff.\n";
    return (1,0);
  }

  if ($numdiffs == 0)
  {
    print "Output looks good.\n";

    unlink "$output_filename";
    unlink "$output_filename.diff";
    return (1,1);
  }
}

1;
