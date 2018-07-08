#!/usr/bin/perl

use strict;

# For PRIVATE Module::Install extensions
use lib 'private-lib';

use lib '.';
use inc::Module::Install;

# To prevent MakeMaker from processing our old directory
BEGIN { makemaker_args( NORECURS => 1 ) }

# Do all_from first to get the required perl version before
# check_custom_installation runs
name('grepmail');
all_from('grepmail');

auto_set_bugtracker;
githubmeta;

provides(
  'grepmail' => {
    file => 'grepmail',
    version => version(),
  }
);

check_custom_installation();

install_script('grepmail');

configure_requires(
  'File::Slurper' => 0,
  # Module::Install::Bugtracker needs this
  'URI::Escape' => 0,
);

requires(
  'Date::Parse' => 0,
  'Mail::Mbox::MessageParser' => '1.4001',
  # I don't really require such a new version, but some old OSes have a
  # version 1.11 that doesn't work right. Updating to the "real" 1.11 does
  # work right. Repro'd on a RHEL 5 Update 11 VM in AWS, running perl 5.8.8.
  'Time::Local' => '1.2300',
);

test_requires(
  'Test::Compile' => 0,
  'Test::More' => 0,
  'File::Slurper' => 0,
);

check_optional('Digest::MD5' => 0, "Digest::MD5 reduces memory consumption for the -u (unique) option\n");

check_optional('Date::Manip' => 0, "Date::Manip allows you to use complex date patterns for the -d option\n");

check_optional('Benchmark::Timer' => 0, "Benchmark::Timer is required for speed tests\n");

Add_Test_Target('testspeed', 't/speed.pl');

license 'gpl';
auto_license(holder => 'David Coppit');

no_index 'directory' => 'private-lib';

enable_verbose_cpan_testing();

WriteAll();

# ---- Workaround for broken module ----
# https://rt.cpan.org/Ticket/Display.html?id=125772
{
  package Module::Install::StandardTests;

  sub write_standard_test_compile {
      my $self = shift;
      $self->write_test_file('000_standard__compile.t', q/
          BEGIN {
            if ($^O eq 'MSWin32') {
              require Test::More;
              Test::More->import(skip_all =>
                  "Test::Compile doesn't work properly on Windows");
            } else {
              require Test::More;
              Test::More->import();
              eval "use Test::Compile";
              Test::More->builder->BAIL_OUT(
                  "Test::Compile required for testing compilation") if $@;
              all_pm_files_ok();
            }
          }
      /);
  }
}

use_standard_tests;

fix_standard_tests('grepmail');

Update_Test_Version('grepmail','t/results/help');
