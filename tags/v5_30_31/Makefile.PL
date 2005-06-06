#!/usr/bin/perl

use strict;
# For PRIVATE Module::Install extensions
use lib 'lib';
use inc::Module::Install;

Check_Custom_Installation();

print "\n", '-'x78, "\n\n";

name              ('grepmail');
author            ('David Coppit <david@coppit.org>');
abstract_from     ('grepmail');
version_from      ('grepmail');
license           ('gpl');

install_script    ('grepmail');

build_requires    (
                    'Test::More' => 0,
                  );

requires          (
                    'perl' => '5.004',
                    'Date::Parse' => 0,
                    'Mail::Mbox::MessageParser' => '1.2130',
                  );

postamble         (
' 
testspeed :: pure_all
        PERL_DL_NONLAZY=1 $(PERLRUN) "-I$(INST_LIB)" \
          "-I$(INST_ARCHLIB)" t/speed.pl
'
);

# Optional features and their modules
features          (
                    'Reduced Memory Consumption for -u' => [
                      -default => 0,
                      recommends( 'Digest::MD5' => 0 ),
                    ],
                    'Complex Date Patterns' => [
                      -default => 1,
                      recommends( 'Date::Manip' => 0 ),
                    ],
                    'Speed Tests' => [
                      -default => 0,
                      recommends( 'Benchmark::Timer' => '0.7100' ),
                    ],
                  );

include           ('ExtUtils/AutoInstall.pm');

clean_files       ('t/temp');

auto_include_deps ( );
auto_install      ( );
WriteAll();

print "\n", '-'x78, "\n\n";

Update_Test_Version('grepmail','t/results/help');

exit;
