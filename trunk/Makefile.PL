#!/usr/bin/perl
# use perl                                  -*- mode: Perl; -*-

use strict;
use ExtUtils::MakeMaker;

require 5.004;

@ARGV = Set_Install_Options(@ARGV)
  unless (grep {/^PREFIX=/} @ARGV) || (grep {/^INSTALLDIRS=/} @ARGV);

Configure_Grepmail('grepmail');

print "\n","-"x78,"\n\n";

my %makefile_attributes = Compute_Makefile_Attributes(@ARGV);

WriteMakefile( %makefile_attributes );

UpdateTestVersion('grepmail','t/results/test25.stdout.real');

exit;

# --------------------------------------------------------------------------

sub Set_Install_Options
{
  my @args = @_;

  my $install_location = ExtUtils::MakeMaker::prompt(
    "Choose your installation type:\n[1] normal Perl locations\n" .
    "[2] custom locations\n=>" => '1');

  if ($install_location eq '2')
  {
    my $home = Get_Home_Directory();

    print "\n","-"x78,"\n\n";

    my $prefix = ExtUtils::MakeMaker::prompt(
      "What PREFIX should I use?\n=>" => $home);

    push @args,"PREFIX=$prefix";
  }

  return @args;
}

# --------------------------------------------------------------------------

sub Configure_Grepmail
{
  my $filename = shift;

  print "\n","-"x78,"\n\n";

  print "The following questions are used to configure grepmail.\n";
  print "You can change these settings later by editing the grepmail script.\n\n";

  my $enable_caching = ExtUtils::MakeMaker::prompt(
    "Grepmail can cache email location information from parsed mailboxes,\n" .
    "resulting in 6 times faster execution for later runs. A ~/.grepmail-cache\n" .
    "file is left on the system.\n\n" .
    "Would you like to enable caching?" => 'y');

  my $enable_grep = ExtUtils::MakeMaker::prompt(
    "\nGrepmail can use GNU grep to help get location information for mailboxes,\n" .
    "resulting in 4 times faster execution. Only answer yes to this question\n" .
    "if you have GNU grep.\n\n" .
    "Would you like to enable grep support?" => 'y');

  $enable_caching = $enable_caching =~ /^y/i ? 1 : 0;
  $enable_grep = $enable_grep =~ /^y/i ? 1 : 0;

  local $/ = undef;

  open SOURCE, $filename
    or die "Couldn't open grepmail file: $!";

  my $code = <SOURCE>;
  close SOURCE;

  $code =~ s/^\$USE_CACHING = (\d+);/\$USE_CACHING = $enable_caching;/m;
  $code =~ s/^\$USE_GREP = (\d+);/\$USE_GREP = $enable_grep;/m;

  open SOURCE, ">$filename"
    or die "Couldn't open grepmail file: $!";

  print SOURCE $code;

  close SOURCE;
}

# --------------------------------------------------------------------------

# Figures out the user's home directory in Unix

sub Get_Home_Directory()
{
  # Get the user's home directory. First try the password info, then the
  # registry (if it's a Windows machine), then any HOME environment variable.
  my $home = eval { (getpwuid($>))[7] } || $ENV{HOME};

  die <<"  EOF"
Your home directory could not be determined. I tried to get your
home directory using both getpwuid and your HOME environment variable.
  EOF
    unless defined $home;

  return $home;
}

# --------------------------------------------------------------------------

sub Compute_Makefile_Attributes
{
  my @args = @_;

  my %makefile_attributes = (
    'NAME'  => 'grepmail',
    'VERSION_FROM' => 'grepmail',

    'dist'  => { COMPRESS => 'gzip -9', SUFFIX => 'gz' },
    'clean' => { FILES => 't/temp' },
    'EXE_FILES' => [ 'grepmail' ],
    'PREREQ_PM' => {
      'Date::Parse' => 0,
      'Mail::Mbox::MessageParser' => 0,
    },
    'DIR' => [],
  );

  return %makefile_attributes;
}

# --------------------------------------------------------------------------

sub UpdateTestVersion
{
  my $file_with_version = shift;
  my $test_case_file = shift;

  print "Updating version number in test case 25.\n";

  open SOURCE, $file_with_version
    or die "Couldn't open grepmail file: $!";

  while (my $line = <SOURCE>)
  {
    if ($line =~ /\$VERSION = '(.*?)';/)
    {
      my $version = $1;

      open TEST_CASE, $test_case_file
        or die "Couldn't open test case: $!";

      local $/ = undef;
      my $test_case_code = <TEST_CASE>;

      $test_case_code =~ s/^grepmail .*$/grepmail $version/m;

      close TEST_CASE;

      unlink $test_case_file;

      open TEST_CASE, ">$test_case_file"
        or die "Couldn't open test case for updating: $!";

      print TEST_CASE $test_case_code;

      close TEST_CASE;

      last;
    }
  }

  close SOURCE;
}

# --------------------------------------------------------------------------

# So that "SUPER" works right
package MY;

sub test {
  my $inherited = shift->SUPER::test(@_);
  $inherited =~ s#'\)" \$\(TEST_FILES\)#', 'lib'\)" \$\(TEST_FILES\)#;
  $inherited =~ s#"-I\$\(INST_ARCHLIB\)" \$\(TEST_FILE\)#"-I\$\(INST_ARCHLIB\)" "-Ilib" \$\(TEST_FILE\)#;
  $inherited;
}

# --------------------------------------------------------------------------

sub postamble
{
# Add a target for testing the speed, and one for testing
# functionality
'
testspeed :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-I$(INST_LIB)" \
	  "-I$(INST_ARCHLIB)" "-Ilib" t/speed.pl

testfunc :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-I$(INST_LIB)" \
	  "-I$(INST_ARCHLIB)" "-Ilib" t/*.t
';
}

