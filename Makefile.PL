#!/usr/bin/perl
# use perl                                  -*- mode: Perl; -*-

use strict;

use ExtUtils::MakeMaker;

require 5.004;

# --------------------------------------------------------------------------

my %makefile_attributes=(
  # For debugging
  #'NOECHO' => '',
  'NAME'  => 'grepmail',
  'VERSION_FROM' => 'grepmail',

  'dist'  => { COMPRESS => 'gzip -9', SUFFIX => 'gz' },
  'clean' =>
    { FILES => 't/results/*.diff t/results/*.stdout t/results/*.stderr' },
  'EXE_FILES' => ['grepmail'],
  'PREREQ_PM' => {'Date::Parse' => 0},
);

unless (@ARGV)
{
  print <<EOF;
Do you want to install the Mail::Folder::FastReader module? This
module was written to help speed up grepmail's mailbox processing. It
can speed things up by 10-20% (y/n)
EOF
  my $response = <STDIN>;

  if ($response =~ /^n/i)
  {
    $makefile_attributes{'DIR'} = [];
  }
}

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

WriteMakefile( %makefile_attributes );
