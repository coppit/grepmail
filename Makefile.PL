#!/usr/bin/perl
# use perl                                  -*- mode: Perl; -*-

use strict;
use ExtUtils::MakeMaker;
use lib 'lib';
use Test::ConfigureGrepmail;

require 5.004;

unless ((grep {/^PREFIX=/} @ARGV) || (grep {/^INSTALLDIRS=/} @ARGV))
{
  @ARGV = Set_Install_Options(@ARGV);
}

print "\n","-"x78,"\n\n";

my %makefile_attributes = Compute_Makefile_Attributes();

WriteMakefile( %makefile_attributes );

print "\n","-"x78,"\n\n";

UpdateTestVersion('grepmail','t/results/help');

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

sub Compute_Makefile_Attributes
{
  my %makefile_attributes = (
    'NAME'  => 'grepmail',
    'VERSION_FROM' => 'grepmail',

    'dist'  => { COMPRESS => 'gzip -9', SUFFIX => 'gz' },
    'clean' => { FILES => 't/temp' },
    'EXE_FILES' => [ 'grepmail' ],
    'PM' => {},
    'PREREQ_PM' => {
      'Date::Parse' => 0,
      'Mail::Mbox::MessageParser' => 1.10,
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

# ---------------------------------------------------------------------------

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

# So that "SUPER" works right
package MY;

sub postamble
{
'
testspeed :: pure_all
	PERL_DL_NONLAZY=1 $(PERLRUN) "-I$(INST_LIB)" \
	  "-I$(INST_ARCHLIB)" t/speed.pl
';
}

