#!/usr/bin/perl -w

# grepmail

$VERSION = 4.22;

# Grepmail searches a normal, gzip'd, tzip'd, or bzip2'd mailbox for a given
# regular expression and returns those emails that match the query. It also
# supports piped compressed or ascii input, and searches constrained by date
# and size. 

# Visit the grepmail project homepage at http://grepmail.sourceforge.net/
# There you can join the announcements mailing list to be notified of updates,
# grab the development environment via CVS, participate in chats and mailing
# lists, report bugs, submit patches, etc.

# Do a pod2text on this file to get full documentation, or pod2man to get
# man pages.

# Written by David Coppit (david@coppit.org, http://coppit.org/)

# This code is distributed under the GNU General Public License (GPL). See
# http://www.opensource.org/gpl-license.html and http://www.opensource.org/.

# Notes:
# It turns out that -h, -b, -d, -s and -v have some nasty feature interaction.
# Here's a table of how matching should occur for each combination of flags:
#
# % B, H, S, D,!V
#   Match if body, header, size, and date match
# %!B, H, S, D,!V
#   Match if header, size, and date match -- don't care about body
# % B,!H, S, D,!V
#   Match if body, size, and date match -- don't care about header
# % B, H,!S, D,!V
#   Match if body, header, and date match -- don't care about size
# % B, H, S,!D,!V
#   Match if body, header, and size match -- don't care about date
# %!B,!H, S, D,!V
#   Match if size and date and (body or header) matches
#*%!B, H,!S, D,!V
#   Match if header and date matches -- don't care about body or size
# %!B, H, S,!D,!V
#   Match if header and size matches -- don't care about body or date
# % B,!H,!S, D,!V
#   Match if body and date matches -- don't care about header or size
# % B,!H, S,!D,!V
#   Match if body and size matches -- don't care about header or date
# % B, H,!S,!D,!V
#   Match if body and header matches -- don't care about size or date
#*%!B,!H,!S, D,!V
#   Match if date and (body or header) matches -- don't care about size
# %!B,!H, S,!D,!V
#   Match if size and (body or header) matches -- don't care about date
#*%!B, H,!S,!D,!V
#   Match if header matches -- don't care about body, size, or date
#   B,!H,!S,!D,!V
#   Match if body matches -- don't care about header, size, or date
#*  B, H, S, D, V
#   Match if body, header, size, or date doesn't match
#* !B, H, S, D, V
#   Match if header, size, or date doesn't match -- don't care about body
#*  B,!H, S, D, V
#   Match if body, size, or date doesn't match -- don't care about header
#*  B, H,!S, D, V
#   Match if body, header, or date doesn't match -- don't care about size
#*  B, H, S,!D, V
#   Match if body, header, or size doesn't match -- don't care about date
#* !B,!H, S, D, V
#   Match if size or date doesn't match -- don't care about body or header
#*%!B, H,!S, D, V
#   Match if header or date doesn't match -- don't care about body or size
#* !B, H, S,!D, V
#   Match if header or size doesn't match -- don't care about body or date
#*  B,!H,!S, D, V
#   Match if body or date doesn't match -- don't care about header or size
#*  B,!H, S,!D, V
#   Match if body or size doesn't match -- don't care about header or date
#*  B, H,!S,!D, V
#   Match if body or header doesn't match -- don't care about size or date
#*%!B,!H,!S, D, V
#   Match if date or (body and header) don't match -- don't care about size
#* !B,!H, S,!D, V
#   Match if size or (body and header) don't match -- don't care about date
#*%!B, H,!S,!D, V
#   Match if header doesn't match -- don't care about body, size, or date
#   B,!H,!S,!D, V
#   Match if body doesn't match -- don't care about header, size, or date
#
#* Indicates early match candidate based on the header only
#% Indicates early nonmatch candidate based on the header only

require 5.00396;

use vars qw(%opts $pattern $commandLine $VERSION $DEBUG);

use Getopt::Std;

use strict;
use FileHandle;
use Carp;

#-------------------------------------------------------------------------------

# Outputs debug messages with the -D flag. Be sure to return 1 so code like
# 'dprint "blah\n" and exit' works.

sub dprint
{
  return 1 unless $DEBUG;

  my $message = join '',@_;

  my @lines = split /\n/, $message;
  foreach my $line (@lines)
  {
    print "DEBUG: $line\n";
  }

  return 1;
}

#-------------------------------------------------------------------------------

# Perform a clean exit with CTRL-C is caught, a pipe is empty, a pipe is
# killed, etc.

sub cleanExit
{
  my $message;

  $message = shift || "Cancelled";
  print STDERR "grepmail: $message.\n";

  exit 1;
}

#-------------------------------------------------------------------------------

$commandLine = "$0 @ARGV";

# So we don't have to test whether they are defined later.
$opts{'D'} = $opts{'d'} = $opts{'e'} = $opts{'i'} = $opts{'q'} = 0;
$opts{'h'} = $opts{'b'} = $opts{'v'} = $opts{'l'} = $opts{'r'} = 0;
$opts{'M'} = $opts{'m'} = $opts{'s'} = 0;

# Print usage error if no arguments given
print "No arguments given. grepmail -h for help.\n" and exit if (!@ARGV);

getopt("eds",\%opts);

$DEBUG = $opts{'D'} || 0;

dprint "Command line was:";
dprint "  $commandLine";

# Here we have to deal with the possibility that the user specified the search
# pattern without the -e flag. They have to use the -e flag if the pattern
# lies after the -d and -s flags (if either are specified). This is to
# disambiguate the pattern and the file list.

# If there was no -e, and it doesn't look like they specified the pattern in
# the middle of the flags, we assume there was no pattern and set a default
# pattern of "." to match everything.
if (( $opts{'d'} &&  $opts{'s'} && !$opts{'e'}) ||
    ( $opts{'d'} && !$opts{'s'} && !$opts{'e'} &&
      $#ARGV > 0 && $ARGV[1] ne '-s') ||
    (!$opts{'d'} &&  $opts{'s'} && !$opts{'e'} &&
      $#ARGV > 0 && $ARGV[1] ne '-d'))
{
  $pattern = ".";
}
# But if we've only seen one of -s or -d so far, there could be a pattern
# specified without a -e flag followed by the other -s or -d.
elsif ($opts{'d'} && !$opts{'s'} && !$opts{'e'} &&
       $#ARGV > 0 && $ARGV[1] eq "-s")
{
  $pattern = shift @ARGV;
  getopt("s",\%opts);
}
elsif (!$opts{'d'} && $opts{'s'} && !$opts{'e'} &&
       $#ARGV > 0 && $ARGV[1] eq "-d")
{
  $pattern = shift @ARGV;
  getopt("d",\%opts);
}
# We could also have the pattern first without -e, then maybe the -s or -d
# flags.
elsif (!$opts{'s'} && !$opts{'d'} && !$opts{'e'} &&
       $#ARGV > 0)
{
  $pattern = shift @ARGV;
  getopt("ds",\%opts);
}
# If we still don't have a pattern or any -d or -s flag, and there is
# something left on @ARGV, we assume that $ARGV[0] is the pattern
elsif (!$opts{'e'} && !$opts{'d'} && !$opts{'s'})
{
  $pattern = shift @ARGV;
}

if ($DEBUG)
{
  dprint "Options are:";
  foreach my $i (sort keys %opts)
  {
    dprint "  $i: $opts{$i}";
  }

  dprint "INC is:";
  foreach my $i (@INC)
  {
    dprint "  $i";
  }
}

if ($opts{'e'})
{
  print "You specified two search patterns.\n" and exit if defined $pattern;
  $pattern = $opts{'e'};
}
elsif (!defined $pattern)
{
  # The only time you can't specify the pattern is when -d is being used.
  # This should catch people who do "grepmail -h" thinking it's help.
  print usage() and exit unless $opts{'d'};

  $pattern = ".";
}

if ($opts{'d'})
{
  unless (eval "require Date::Manip")
  {
    print "You specified -d, but do not have Date::Manip. Get it from CPAN.\n";
    exit;
  }

  import Date::Manip;
}

################################ MAIN PROGRAM #################################

# Make the pattern insensitive if we need to
$pattern = "(?i)$pattern" if ($opts{'i'});

my ($dateRestriction, $date1, $date2);

if ($opts{'d'})
{
  ($dateRestriction,$date1,$date2) = ProcessDate($opts{'d'});
}
else
{
  $dateRestriction = "none";
}

dprint "PATTERN: $pattern\n";
dprint "FILES: @ARGV\n";
dprint "DATE RESTRICTION: $dateRestriction\n";
dprint "SIZE RESTRICTION: $opts{'s'}\n";

# Catch everything I can... We have to localize these to prevent odd bugs from
# cropping up (see changelog).
local $SIG{PIPE} = \&cleanExit;
local $SIG{HUP} = \&cleanExit;
local $SIG{INT} = \&cleanExit;
local $SIG{QUIT} = \&cleanExit;
local $SIG{TERM} = \&cleanExit;

my @files = GetFiles(@ARGV);

# If the user provided input files...
if (@files)
{
  HandleInputFiles(@files);
}
# Using STDIN
else
{ 
  HandleStandardInput();
}

#-------------------------------------------------------------------------------

# Get a list of files, taking recursion into account if necessary.

sub GetFiles(@)
{
  my @args = @_;

  # We just return what we were given unless we need to recurse subdirectories.
  return @args unless defined $opts{'R'};

  my @files;

  foreach my $arg (@args)
  {
    if (-f $arg)
    {
      push @files, $arg;
    }
    elsif( -d $arg)
    {
      dprint "Recursing directory $arg looking for files...";

      unless (eval "require File::Find;")
      {
        print "You specified -R, but do not have File::Find. ".
              "Get it from CPAN.\n";
        exit;
      }

      import File::Find;

      # Gets all plain files in directory and descendents. Puts them in @files
      $File::Find::name = '';
      find(sub {push @files,"$File::Find::name" if -f $_}, $arg);
    }
    else
    {
      # Ignore unknown file types
    }
  }

  return @files;
}

#-------------------------------------------------------------------------------

sub HandleInputFiles
{
  my @files = @_;

  # For each input file...
  foreach my $file (@files)
  {
    dprint '#'x70;
    dprint "Processing file $file";

    # First of all, silently ignore empty files...
    next if -z $file;

    # ...and also ignore directories.
    if (-d $file)
    {
      warn "** Skipping directory: '$file' **\n" unless $opts{'q'};
      next;
    }

    my $fileHandle = new FileHandle;
    my ($filter,$filterError);

    # If it's not a compressed file
    if ($file !~ /\.(gz|Z|bz2|tz)$/)
    {
      if (-B $file)
      {
        warn "** Skipping binary file: '$file' **\n" unless $opts{'q'};
        next;
      }

      unless ($fileHandle->open($file))
      {
        warn "** Can't open $file: $!, skipping **\n" unless $opts{'q'};
        next;
      }
    }
    # If it is a tzipped file
    elsif ($file =~ /\.tz$/)
    {
      dprint "Calling tzip to decompress file.";

      $filter = 'tzip';

      use vars qw(*OLDSTDERR);
      open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
      open STDERR,">/dev/null"
        or die "Can't redirect STDERR to /dev/null: $!\n";

      unless ($fileHandle->open("tzip -cd '$file'|"))
      {
        $filterError = $!;
      }

      open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";
    }
    # If it is a gzipped file
    elsif ($file =~ /\.(gz|Z)$/)
    {
      dprint "Calling gunzip to decompress file.";

      $filter = 'gunzip';

      use vars qw(*OLDSTDERR);
      open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
      open STDERR,">/dev/null"
        or die "Can't redirect STDERR to /dev/null: $!\n";

      unless ($fileHandle->open("gunzip -c '$file'|"))
      {
        $filterError = $!;
      }

      open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";
    }
    # If it is a bzipped file
    elsif ($file =~ /\.bz2$/)
    {
      dprint "Calling bzip2 to decompress file.";

      $filter = 'bzip2';

      use vars qw(*OLDSTDERR);
      open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
      open STDERR,">/dev/null"
        or die "Can't redirect STDERR to /dev/null: $!\n";

      unless ($fileHandle->open("bzip2 -dc '$file'|"))
      {
        $filterError = $!;
      }

      open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";
    }

    if ($filterError)
    {
      warn "** Can't execute \"$filter\" for file \"$file\": $filterError, ".
           "skipping **\n" unless $opts{'q'};
      next;
    }

    unless (DataOnFileHandle($fileHandle))
    {
      unless ($fileHandle->close())
      {
        warn "** Can't execute \"$filter\" for file \"$file\": $!, ".
             "skipping **\n" unless $opts{'q'};
      }
      next;
    }

    if (!IsMailbox($fileHandle))
    {
      warn "** Skipping non-mailbox ASCII file: '$file' **\n" unless $opts{'q'};
      next;
    }

    ProcessMailFile($fileHandle,$file);

    $fileHandle->close();
  }
}

#-------------------------------------------------------------------------------

sub HandleStandardInput
{
  dprint "Handling STDIN";

  # We have to implement our own -B and -s, because STDIN gets eaten by them
  binmode STDIN;

  my ($testChars,$isEmpty,$isBinary);

  my $fileHandle = new FileHandle;
  $fileHandle->open('-');

  $isEmpty = 0;
  $isBinary = 0;

  my $readResult = read($fileHandle,$testChars,200);

  cleanExit "Can't read from standard input" unless defined $readResult;

  $isEmpty = 1 if $readResult == 0;

  cleanExit "No data on standard input" if $isEmpty;

  # This isn't the "real" way to do -B, but it should work okay.
  $isBinary = 1 if !$isEmpty &&
                    ($testChars =~ /\000/ || $testChars =~ /[\200-\377]/);

  PutBackString($fileHandle,$testChars);

  # If it looks binary and is non-empty, try to uncompress it. Here we're
  # calling another copy of grepmail through the open command.
  if ($isBinary)
  {
    my $filter;

    # This seems to work. I'm not sure what the "proper" way to distinguish
    # between gzip'd and bzip2'd and tzip'd files is.
    if ($testChars =~ /^TZ/)
    {
      dprint "Trying to decompress using tzip.";
      $filter = "tzip -dc";
    }
    elsif ($testChars =~ /^BZ/)
    {
      dprint "Trying to decompress using bzip2.";
      $filter = "bzip2 -d";
    }
    else
    {
      dprint "Trying to decompress using gunzip.";
      $filter = "gunzip -c";
    }

    # Here we invoke another copy of grepmail with a filter in front.
    use vars qw(*OLDSTDERR);
    open OLDSTDERR,">&STDERR" or die "Can't save STDERR: $!\n";
    open STDERR,">/dev/null"
      or die "Can't redirect STDERR to /dev/null: $!\n";

    my $newGrepmail = new FileHandle;
    $newGrepmail->open("|$filter|$commandLine")
      or warn "** Can't execute \"$filter\" on STDIN: $! **\n"
        unless $opts{'q'};

    open STDERR,">&OLDSTDERR" or die "Can't restore STDERR: $!\n";

    while (!eof $fileHandle)
    {
      my $temp = <$fileHandle>;
      print $newGrepmail $temp;
    }

    $newGrepmail->close()
      or warn "** Can't execute \"$filter\" on STDIN: $! **\n"
        unless $opts{'q'};
  }
  # Otherwise process it directly
  else
  {
    if (!IsMailbox($fileHandle))
    {
      warn "** Skipping non-mailbox standard input **\n" unless $opts{'q'};
      return;
    }

    ProcessMailFile($fileHandle,"Standard input");
  }
}

#-------------------------------------------------------------------------------

# Checks to see if there is data on a filehandle, without reading that data.

sub DataOnFileHandle
{
  my $fileHandle = shift;

  my $buffer = <$fileHandle>;
  PutBackString($fileHandle,$buffer);

  return $buffer ? 1 : 0;
}

#-------------------------------------------------------------------------------

# Puts a string back on a file handle

sub PutBackString
{
  my $fileHandle = shift;
  my $string = shift;

  while ($string ne '')
  {
    my $char = chop $string;
    $fileHandle->ungetc(ord($char));
  }
}

#-------------------------------------------------------------------------------

# Detects whether an ASCII file is a mailbox, based on whether it has a 'From'
# and 'Date:' prefix on two lines of the first paragraph.

sub IsMailbox
{
  my $fileHandle = shift @_;

  # Read whole paragraphs
  local $/ = "\n\n";

  # Read a paragraph to get the header.
  my $buffer = <$fileHandle>;

  my $returnVal;
  if ($buffer =~ /^From /im && $buffer =~ /^Date: /im)
  {
    $returnVal = 1;
  }
  else
  {
    $returnVal = 0;
  }

  PutBackString($fileHandle,$buffer);

  return $returnVal;
}

#-------------------------------------------------------------------------------

sub ProcessMailFile ($$)
{
  my $fileHandle = shift @_;
  my $fileName = shift @_;

  # $header_buffer stores the header for the current email. $body_buffer
  # stores the body for the current email. $next_header stores the header for
  # the next email, in case we encounter it while looking for the end of the
  # current email.

  # I'd really like to call PushBackString instead of storing $next_header,
  # but that way is much slower, and fails unpredictably. :( The next best
  # solution is to write a wrapper class for FileHandle that allows pushbacks,
  # and stores them in an internal buffer. Too much work for now though...

  my ($numberOfMatches,$header_buffer,$body_buffer,$next_header);

  $next_header = undef;
  $numberOfMatches = 0;

  # Read whole paragraphs
  local $/ = "\n\n";

  # This is the main loop. It's executed once for each email
  while (!eof($fileHandle))
  {
    $header_buffer = '';
    $body_buffer = '';

    if (!defined $next_header)
    {
      dprint "Getting header for first email.";

      $header_buffer = <$fileHandle>;
    }
    else
    {
      dprint "Processing buffered header.";
      $header_buffer = $next_header;

      undef $next_header;
    }

    PrintEmailStatistics($header_buffer) if $DEBUG;

    #----------------------------------------------------------------

    dprint "Checking for early match or abort based on header information.";
    my ($result,$matchesHeader) =
      AnalyzeHeader(\$header_buffer,$fileHandle,\$next_header,$pattern);

    if ($result eq 'skip')
    {
      dprint "Doing an early abort based on header.";
      SkipToNextEmail($fileHandle,\$next_header,$fileName);
      next;
    }
    elsif ($result eq 'print')
    {
      dprint "Doing an early printout based on header.";
    
      if ($opts{'l'})
      {
        print "$fileName\n";
    
        # We can return since we found at least one email that matches.
        return 'done';
      }
      elsif ($opts{'r'})
      {
        $numberOfMatches++;
        SkipToNextEmail($fileHandle,\$next_header,$fileName);
      }
      else
      {
        GetRestOfBody($fileHandle,\$body_buffer,\$next_header,$fileName);
        PrintEmail($fileName,$header_buffer,$body_buffer);
        next;
      }
    }

    dprint "Couldn't do an early printout or abort based on header.";

    #----------------------------------------------------------------

    dprint "Reading body.";

    GetRestOfBody($fileHandle,\$body_buffer,\$next_header,$fileName);

    my $matchesBody;

    # Ignore the MIME attachments if -M was specified
    if ($opts{'M'} &&
        (($header_buffer =~ /\nContent-Type:.*?boundary="([^"]*)"/is) ||
        ($header_buffer =~ /\nContent-Type:.*?boundary=([^\n]*)/is)))
    {
      my $boundary = $1;

      my $tempBody = $body_buffer;

      # Strip out any attachments that aren't textual
      $tempBody =~ s/\Q$boundary\E\nContent-Type: (?!text).*?(?=$boundary)//igs;

      $matchesBody = ($tempBody =~ /$pattern/om) || 0;
    }
    else
    {
      $matchesBody = ($body_buffer =~ /$pattern/om) || 0;
    }

    #----------------------------------------------------------------

    dprint "Total email size is: ",length ($header_buffer.$body_buffer),"\n";
    my $matchesSize = length $header_buffer.$body_buffer < $opts{'s'} ? 1 : 0;

    dprint "Checking for early match or abort based on header+body information.";

    my $isMatch = 1;
    
    $isMatch = 0 if  $opts{'s'} && !$matchesSize;
    $isMatch = 0 if  $opts{'b'} && !$matchesBody;
    $isMatch = 0 if                 $opts{'h'} && !$matchesHeader;
    $isMatch = 0 if !$opts{'b'} && !$opts{'h'} && !($matchesBody || $matchesHeader);

    if ($isMatch == 0 && !$opts{'v'})
    {
      dprint "Doing an early abort based on header+body.";
      SkipToNextEmail($fileHandle,\$next_header,$fileName);
      next;
    }
    elsif ($isMatch == 0 && $opts{'v'})
    {
      dprint "Doing an early printout based on header+body.";
    
      if ($opts{'l'})
      {
        print "$fileName\n";
    
        # We can return since we found at least one email that matches.
        return 'done';
      }
      elsif ($opts{'r'})
      {
        $numberOfMatches++;
        SkipToNextEmail($fileHandle,\$next_header,$fileName);
      }
      else
      {
        GetRestOfBody($fileHandle,\$body_buffer,\$next_header,$fileName);
        PrintEmail($fileName,$header_buffer,$body_buffer);
        next;
      }
    }

    dprint "Couldn't do an early printout or abort based on header+body.";

    $isMatch = 1;
    
    my $matchesDate = CheckDate(\$header_buffer);
    $isMatch = 0 if $opts{'d'} && !$matchesDate;

    $isMatch = !$isMatch if $opts{'v'};

    # If the match occurred in the right place...
    if ($isMatch)
    {
      dprint "Email matches all patterns and constraints.";

      if ($opts{'l'})
      {
        print "$fileName\n";

        # We can return since we found at least one email that matches.
        return 'done';
      }
      elsif ($opts{'r'})
      {
        $numberOfMatches++;
      }
      else
      {
        PrintEmail($fileName,$header_buffer,$body_buffer);
      }
    }
    else
    {
      dprint "Did not find a pattern match on the body.";
    }
  }

  print "$fileName: $numberOfMatches\n" if ($opts{'r'});
}

#-------------------------------------------------------------------------------

# Print the email author and subject.

sub PrintEmailStatistics
{
  my $header = shift;

  dprint '-'x70;
  dprint "Processing email:";

  if ($header =~ /^(From:.*)$/im)
  {
    dprint "  $1";
  }
  elsif ($header =~ /^(From.*)$/im)
  {
    dprint "  $1";
  }
  else
  {
    dprint "  [No from line found]";
  }

  if ($header =~ /^(Subject:.*)$/im)
  {
    dprint "  $1";
  }
  else
  {
    dprint "  [No subject line found]";
  }
}

#-------------------------------------------------------------------------------

# Returns:
# A result:
# - 'print' if the email is a match and we need to print it
# - 'skip' if we should skip the current email and go on to the next one
# - 'continue' if we need to keep processing the email.
# A boolean for whether the header matches the pattern.
# A boolean for whether the header has the correct date.

sub AnalyzeHeader(\$$\$$)
{
  my $header_buffer = ${shift @_};
  my $fileHandle = shift;
  my $next_header = ${shift @_};
  my $pattern = shift;

  # See if the header matches the pattern
  my $matchesHeader = ($header_buffer =~ /$pattern/om) || 0;

  # See if the email failed the size restriction. If it passes here, we still
  # don't know if the entire length of the email is too long.
  my $matchesSize = length $header_buffer < $opts{'s'} ? 1 : 0;

  # At this point, we might know enough to print the email, or call for an
  # early abort. See the documentation at the top for information. These
  # conditions have been simplified to save space at the cost of clarity.
  # Also, all date related conditions have been taken out, and will be handled
  # after the pattern is searched for in the body of the email. This is
  # because searching for the pattern is a lot faster than handling the date,
  # and we don't have to handle the date if the pattern isn't found.
  
  # First handle the situations where a date constraint isn't a factor.
  return ('print',1) if (
      (!$opts{'b'} &&  $opts{'h'} && !$opts{'s'} && !$opts{'d'} &&
       !$opts{'v'} && $matchesHeader) ||
      (                $opts{'h'} &&  $opts{'s'} && !$opts{'d'} &&
        $opts{'v'} && (!$matchesHeader || !$matchesSize)) ||
      (                !$opts{'h'} &&  $opts{'s'} && !$opts{'d'} &&
        $opts{'v'} && (!$matchesSize)) ||
      (                $opts{'h'} && !$opts{'s'} && !$opts{'d'} &&
        $opts{'v'} && (!$matchesHeader)) ||

      (                $opts{'h'} &&  $opts{'s'} &&  $opts{'d'} &&
        $opts{'v'} && (!$matchesHeader || !$matchesSize)) ||
      (               !$opts{'h'} &&  $opts{'s'} &&  $opts{'d'} &&
        $opts{'v'} && (!$matchesSize)) ||
      (                $opts{'h'} && !$opts{'s'} &&  $opts{'d'} &&
        $opts{'v'} && (!$matchesHeader))
    );

  return ('skip',0) if (
      (                $opts{'h'} &&  $opts{'s'} && !$opts{'d'} &&
       !$opts{'v'} && (!$matchesHeader || !$matchesSize)) ||
      (               !$opts{'h'} &&  $opts{'s'} && !$opts{'d'} &&
       !$opts{'v'} && (!$matchesSize)) ||
      (                $opts{'h'} && !$opts{'s'} && !$opts{'d'} &&
       !$opts{'v'} && (!$matchesHeader)) ||
      (!$opts{'b'} &&  $opts{'h'} && !$opts{'s'} && !$opts{'d'} &&
        $opts{'v'} && ($matchesHeader)) ||

      (                $opts{'h'} &&  $opts{'s'} &&  $opts{'d'} &&
       !$opts{'v'} && (!$matchesHeader || !$matchesSize)) ||
      (               !$opts{'h'} &&  $opts{'s'} &&  $opts{'d'} &&
       !$opts{'v'} && (!$matchesSize)) ||
      (                $opts{'h'} && !$opts{'s'} &&  $opts{'d'} &&
       !$opts{'v'} && (!$matchesHeader))
    );

  return ('continue',$matchesHeader);
}

#-------------------------------------------------------------------------------

sub SkipToNextEmail($\$$)
{
  my $fileHandle = shift;
  my $next_header = shift;
  my $fileName = shift;
  my $paragraph;

  dprint "Skipping to next email.";

  # If we have something buffered, it's the beginning of the next email
  # address, so we don't need to do anything. Joy.
  return if defined $$next_header;

  do
  {
    $paragraph = <$fileHandle>;
  }
  while (!eof($fileHandle) && ($paragraph !~ /^\n?From .*\d:\d+:\d.* \d{4}/i)) ;

  # Buffer if we went too far. Zap the starting newline while we're at it.
  ($$next_header) = $paragraph =~ /^\n?(.*)/s if (!eof($fileHandle));
}

#-------------------------------------------------------------------------------

sub GetRestOfBody($\$\$$)
{
  my $fileHandle = shift;
  my $body_buffer = shift;
  my $next_header = shift;
  my $fileName = shift;

  return if defined $$next_header;

  # Read the entire email body into the buffer
  my $doneLooking = 0;
  do
  {
    my $paragraph = <$fileHandle>;

    if (defined $paragraph)
    {
      if ($paragraph =~ /^(\n?)(From .*\d:\d+:\d.* \d{4}.*)/is)
      {
        dprint "Found next email's header, buffering.";
        $$body_buffer .= $1;
        $$next_header = $2;
        $doneLooking = 1;
      }
      else
      {
        $$body_buffer .= $paragraph;
      }
    }

    if (eof($fileHandle))
    {
      dprint "Found EOF.";
      $doneLooking = 1;
    }
  }
  while (!$doneLooking);
}

#-------------------------------------------------------------------------------

sub PrintEmail($$$\$)
{
  my $fileName = shift;
  my $header = shift;
  my $body = shift;

  dprint "Printing email.";

  # Add the mailfolder to the headers if -m was given
  if ($opts{'m'})
  {
    $header =~ s/\n+$/\n/s;
    $header .= "X-Mailfolder: $fileName\n\n";
  }
  print $header;

  # Print whatever body we've read already.
  print $body;
}

#-------------------------------------------------------------------------------

sub CheckDate($)
{
  my $header = ${shift @_};
  my ($emailDate, $isInDate);
  $emailDate = "";
  $isInDate = 0;

  # RFC 822 allows header lines to be continued on the next line, in which case
  # they must be preceded by whitespace. Let's remove the continuations.
  $header =~ s/\n\s+/ /gs;

  if ($opts{'d'})
  {
    # The email might not have a date. In this case, print it out anyway.
    if ($header =~ /^Date:\s*(.*)$/im)
    {
      dprint "Date in email is: $1.";

      my $fixedDate = $1;

      # We have to remove "(GMT+500)" from the end for Date::Manip
      $fixedDate =~ s/\(GMT[^\)]*\)$//;

      # We have to change +500 to +0500 for Date::Manip
      $fixedDate =~ s/([\+\-])(\d\d\d)$/$1.'0'.$2/e;

      $emailDate = ParseDate($fixedDate);
      $isInDate = IsInDate($emailDate,$dateRestriction,$date1,$date2);
    }
    else
    {
      dprint "No date found in email.";

      $isInDate = 1;
    }
  }
  else
  {
    $isInDate = 1;
  }

  return $isInDate;
}

#-------------------------------------------------------------------------------

# Figure out what kind of date restriction they want, and what the dates in
# question are.
sub ProcessDate($)
{
  my $datestring = shift;

  if(!defined($datestring))
  {
    return ("none","","");
  }

  if ($datestring =~ /^before (.*)/i)
  {
    $dateRestriction = "before";
    $date1 = ParseDate($1);
    $date2 = "";

    cleanExit "\"$1\" is not a valid date" if (!$date1);
  }
  elsif ($datestring =~ /^(after |since )(.*)/i)
  {
    $dateRestriction = "after";
    $date1 = ParseDate($2);
    $date2 = "";

    cleanExit "\"$2\" is not a valid date" if (!$date1);
  }
  elsif ($datestring =~ /^between (.*) and (.*)/i)
  {
    $dateRestriction = "between";
    $date1 = ParseDate($1);
    $date2 = ParseDate($2);

    cleanExit "\"$1\" is not a valid date" if (!$date1);
    cleanExit "\"$2\" is not a valid date" if (!$date2);

    # Swap the dates if the user gave them backwards.
    if ($date1 gt $date2)
    {
      my $temp;
      $temp = $date1;
      $date1 = $date2;
      $date2 = $temp;
    }

  }
  elsif (ParseDate($datestring) ne '')
  {
    $dateRestriction = "on";
    $date1 = ParseDate($datestring);
  }
  else
  {
    cleanExit "Invalid date specification. Use \"$0 -h\" for help";
  }

  return ($dateRestriction,$date1,$date2);
}

#-------------------------------------------------------------------------------

sub IsInDate($$$$)
{
  my ($emailDate,$dateRestriction,$date1,$date2);
  $emailDate = shift @_;
  $dateRestriction = shift @_;
  $date1 = shift @_;
  $date2 = shift @_;

  # Here we do the date checking.
  if ($dateRestriction eq "none")
  {
    return 1;
  }
  else
  {
    if ($dateRestriction eq "before")
    {
      if ($emailDate lt $date1)
      {
        return 1;
      }
      else
      {
        return 0;
      }
    }
    elsif ($dateRestriction eq "after")
    {
      if ($emailDate gt $date1)
      {
        return 1;
      }
      else
      {
        return 0;
      }
    }
    elsif ($dateRestriction eq "on")
    {
      if (&UnixDate($emailDate,"%m %d %Y") eq &UnixDate($date1,"%m %d %Y"))
      {
        return 1;
      }
      else
      {
        return 0;
      }
    }
    elsif ($dateRestriction eq "between")
    {
      if (($emailDate gt $date1) && ($emailDate lt $date2))
      {
        return 1;
      }
      else
      {
        return 0;
      }
    }
  }
}

#-------------------------------------------------------------------------------

sub usage
{
<<EOF;
grepmail $VERSION

usage: grepmail [-bDhilmrRv] [-s size] [-d "datespec"] [[-e] <expr>] <files...>

At least one of -s, -d, and -e must be specified, and can appear in any
relative order following the other flags. The -e flag is optional if expr
appears immediately before -s or -d. Files can be plain ASCII or ASCII files
compressed with gzip, tzip, or bzip2. If no file is provided, normal or
compressed ASCII input is taken from STDIN.

-b Search must match body
-d Specify a date range (see below)
-D Debug mode
-e Explicitely name expr (when searching for strings beginning with "-")
-h Search must match header
-i Ignore case in the search expression
-l Output the names of files having an email matching the expression
-M Do not search non-text mime attachments
-m Append "X-Mailfolder: <folder>" to all headers to indicate in which folder
   the match occurred
-q Quiet mode -- don't output warnings
-r Output the names of the files and the number of emails matching the
   expression
-R Recurse directories
-s Restrict results to emails less than a certain size (in bytes)
-v Output emails that don't match the expression

Date specifications must be of the form of:
a date like "today", "1st thursday in June 1992", "05/18/93",
  "12:30 Dec 12th 1880", "8:00pm december tenth",
OR "before", "after", or "since", followed by a date as defined above,
OR "between <date> and <date>", where <date> is defined as above.
EOF
}

#-------------------------------------------------------------------------------

=head1 NAME

grepmail - search mailboxes for mail matching a regular expression

=head1 SYNOPSIS

  grepmail [-bDhilmrRv] [-s size] [-d "datespec"] [[-e] <expr>] <files...>

=head1 DESCRIPTION

=over 2

I<grepmail> looks for mail messages containing a pattern, and prints the
resulting messages on standard out.

By default I<grepmail> looks in both header and body for the specified pattern.

When redirected to a file, the result is another mailbox, which can, in turn,
be handled by standard User Agents, such as I<elm>, or even used as input for
another instance of I<grepmail>.

At least one of B<-e>, B<-d>, or B<-s> must be specified. The pattern is
optional if B<-d> and/or B<-s> is used. The B<-e> flag is optional if the
pattern appears immediately before B<-s> or B<-d>.

=back

=head1 OPTIONS AND ARGUMENTS

Many of the options and arguments are analogous to those of grep.

=over 8

=item B<pattern>

The pattern to search for in the mail message.  May be any Perl regular
expression, but should be quoted on the command line to protect against
globbing (shell expansion). To search for more than one pattern, use the form
"(pattern1|pattern2|...)".

=item B<mailbox>

Mailboxes must be traditional, UNIX C</bin/mail> mailbox format.  The
mailboxes may be compressed by gzip, tzip, or bzip2, in which case
gunzip, tzip, or bzip2 must be installed on the system.

If no mailbox is specified, takes input from stdin, which can be compressed or
not. grepmail's behavior is undefined when ASCII and binary data is piped
together as input.

=item B<-b>

Asserts that the pattern must match in the body of the email.

=item B<-D>

Enable debug mode, which prints diagnostic messages.

=item B<-d>

Date specifications must be of the form of:
  - a date like "today", "yesterday", "5/18/93", "5 days ago", "5 weeks ago",
  - OR "before", "after", or "since", followed by a date as defined above,
  - OR "between <date> and <date>", where <date> is defined as above.

=item B<-e>

Explicitely specify the search pattern. This is useful for specifying patterns
that begin with "-", which would otherwise be interpreted as a flag.

=item B<-h>

Asserts that the pattern must match in the header of the email.

=item B<-i>

Make the search case-insensitive (by analogy to I<grep -i>).

=item B<-l>

Output the names of files having an email matching the expression, (by analogy
to I<grep -l>).

=item B<-M>

Causes grepmail to ignore non-text MIME attachments. This removes false
positives resulting from binaries encoded as ASCII attachments.

=item B<-m>

Append "X-Mailfolder: <folder>" to all email headers, indicating which folder
contained the matched email.

=item B<-q>

Quiet mode. Suppress the output of warning messages about non-mailbox files,
directories, etc.

=item B<-r>

Generate a report of the names of the files containing emails matching the
expression, along with a count of the number of matching emails.

=item B<-R>

Causes grepmail to recurse any directories encountered.

=item B<-s>

Return emails smaller than the size (in bytes) specified with this flag.

=item B<-v>

Invert the sense of the search, (by analogy to I<grep -v>). Note that this
affects only B<-h> and B<-b>, not B<-d>. This results in the set of emails
printed being the complement of those that would be printed without the B<-v>
switch.

=back

=head1 EXAMPLES

Count the number of emails. ("." matches every email.)

  grepmail -r . sent-mail

Get all email larger than 2000 bytes about books

  grepmail books -s 2000 sent-mail

Get all email that you mailed yesterday

  grepmail -d yesterday sent-mail

Get all email that you mailed before the first thursday in June 1998 that
pertains to research:

  grepmail research -d "before 1st thursday in June 1992" sent-mail

Get all email that you mailed before the first of June 1998 that
pertains to research:

  grepmail research -d "before 6/1/92" sent-mail

Get all email you received since 8/20/98 that wasn't about research or your
job, ignoring case:

  grepmail -iv "(research|job)" -d "since 8/20/98" saved-mail

Get all email about mime but not about Netscape. Constrain the search to match
the body, since most headers contain the text "mime":

  grepmail -b mime saved-mail | grepmail Netscape -v

Print a list of all mailboxes containing a message from Rodney. Constrain the
search to the headers, since quoted emails may match the pattern:

  grepmail -hl "^From.*Rodney" saved-mail*

Find all emails with the text "Pilot" in both the header and the body:

  grepmail -hb "Pilot" saved-mail*

Print a count of the number of messages about grepmail in all saved-mail
mailboxes:

  grepmail -br grepmail saved-mail*

=head1 FILES

grepmail will I<not> create temporary files while decompressing compressed
archives. The last version to do this was 3.5. While the new design uses
more memory, the code is much simpler, and there is less chance that email
can be read by malicious third parties. Memory usage is determined by the size
of the largest email message in the mailbox.

=head1 AUTHOR

  David Coppit, <david@coppit.org>, http://coppit.org/

=head1 SEE ALSO

elm(1), mail(1), grep(1), perl(1), printmail(1), Mail::Internet(3)
Crocker,  D.  H., Standard for the
Format of Arpa Internet Text Messages, RFC822.

=cut
