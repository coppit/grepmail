#!/usr/bin/perl
# use perl                                  -*- mode: Perl; -*-

use strict;
use ExtUtils::MakeMaker;

require 5.004;

# This is so that we can leave FASTREADER on the command line. We want to do
# this so that an automatic regeneration of the Makefile (say, if Makefile.PL
# gets changed) won't prompt the user again.
$ExtUtils::MakeMaker::Recognized_Att_Keys{'FASTREADER'} = 1;

@ARGV = Set_Install_Options(@ARGV);

my %makefile_attributes = Compute_Makefile_Attributes(@ARGV);

WriteMakefile( %makefile_attributes );

# --------------------------------------------------------------------------

sub Set_Install_Options
{
  my @args = @_;

  my $printed = 0;

  unless (grep {/^FASTREADER=/} @args)
  {
    $printed = 1;
    @args = Set_FastReader_Interactively(@args);
  }

  unless ((grep {/^PREFIX=/} @args) || (grep {/^INSTALLDIRS=/} @args))
  {
    print "\n","-"x78,"\n\n" if $printed;

    $printed = 1;
    @args = Set_Installation_Type_Interactively(@args);
  }

  return @args;
}

# --------------------------------------------------------------------------

sub Set_FastReader_Interactively
{
  my @args = @_;

  print <<EOF;
Do you want to install the Mail::Folder::FastReader module? This
module was written to help speed up grepmail's mailbox processing. It
can speed things up by 10-20%
EOF
  print "=> [y] ";
  my $response = <STDIN>;

  if ($response =~ /^n/i)
  {
    push @args, 'FASTREADER=0';
  }
  else
  {
    push @args, 'FASTREADER=1';
  }

  return @args;
}

# --------------------------------------------------------------------------

sub Set_Installation_Type_Interactively
{
  my @args = @_;

  print <<EOF;
Choose your installation type:
[1] normal Perl locations
[2] custom locations
EOF

  print "=> [1] ";
  my $response = <STDIN>;
  chomp $response;
  $response = '1' if $response eq '';


  if ($response eq '1')
  {
    push @args, 'INSTALLDIRS=perl';
  }
  else
  {

    my $home = Get_Home_Directory();

    print "\n","-"x78,"\n\n";

    print "What PREFIX should I use?\n";
    print "=> [$home] ";

    my $prefix = <STDIN>;
    chomp $prefix;
    $prefix = $home if $prefix eq '';

    push @args,"PREFIX=$prefix";
  }

  return @args;
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
    'clean' =>
      { FILES => 't/results/*.diff t/results/*.stdout t/results/*.stderr' },
    'EXE_FILES' => [ 'grepmail' ],
    'PREREQ_PM' => { 'Date::Parse' => 0},
  );

  $makefile_attributes{'DIR'} = [] unless grep {/^FASTREADER=1$/} @args;

  return %makefile_attributes;
}

# --------------------------------------------------------------------------

sub MY::postamble
{
# Add a target for testing the speed, and one for testing
# functionality
'
testspeed :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	  -I$(PERL_ARCHLIB) -I$(PERL_LIB) $(TEST_FILE)

testfunc :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) \
	  -I$(PERL_ARCHLIB) -I$(PERL_LIB) t/functionality.t
';
}

