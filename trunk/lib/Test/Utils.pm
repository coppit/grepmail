package Test::Utils;

use strict;
use Exporter;
use Test;
use FileHandle;

use vars qw( @EXPORT @ISA );
use Mail::Mbox::MessageParser;

@ISA = qw( Exporter );
@EXPORT = qw( CheckDiffs DoDiff InitializeCache ModuleInstalled %PROGRAMS
  Broken_Pipe No_such_file_or_directory
);

use vars qw( %PROGRAMS );

%PROGRAMS = (
 'tzip' => undef,
 'gzip' => '/usr/cs/contrib/bin/gzip',
 'compress' => '/usr/cs/contrib/bin/gzip',
 'bzip' => undef,
 'bzip2' => undef,
);

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
    print "Output $output_filename looks good.\n";

    unlink "$output_filename";
    unlink "$output_filename.diff";
    return (1,1);
  }
}

# ---------------------------------------------------------------------------

sub InitializeCache
{
  my $filename = shift;

  Mail::Mbox::MessageParser::SETUP_CACHE({'file_name' => 't/temp/cache'});
  Mail::Mbox::MessageParser::CLEAR_CACHE();

  my $filehandle = new FileHandle($filename);

  my $folder_reader =
      new Mail::Mbox::MessageParser( {
        'file_name' => $filename,
        'file_handle' => $filehandle,
        'enable_cache' => 1,
        'enable_grep' => 0,
      } );

  die $folder_reader unless ref $folder_reader;

  my $prologue = $folder_reader->prologue;

  # This is the main loop. It's executed once for each email
  while(!$folder_reader->end_of_file())
  {
    $folder_reader->read_next_email();
  }

  $filehandle->close();

  Mail::Mbox::MessageParser::WRITE_CACHE();
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

sub No_such_file_or_directory
{
  my $filename = 0;

  $filename++ while -e $filename;

  local $!;

  my $foo = new FileHandle;
  $foo->open($filename);

  die q{Couldn't determine local text for "No such file or directory"}
    if $! eq '';

  return $!;
}

# ---------------------------------------------------------------------------

# I think this works, but I haven't been able to test it because I can't find
# a system which will report a broken pipe. Also, is there a pure Perl way of
# doing this?
sub Broken_Pipe
{
  mkdir 't/temp', 0700;

  open F, ">t/temp/broken_pipe.pl";
  print F<<EOF;
unless (open B, '-|')
{
  open(F, "|cat 2>/dev/null");
  print F 'x';
  close F;
  exit;
}
EOF
  close F;

  my $result = `$^X t/temp/broken_pipe.pl 2>&1 1>/dev/null`;

  $result = '' unless defined $result;

  return $result;
}

# ---------------------------------------------------------------------------

1;
