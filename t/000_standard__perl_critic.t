#!perl -w

use strict;
use warnings;

use FindBin '$Bin';
use File::Spec;
use UNIVERSAL::require;
use Test::More;

plan skip_all =>
    'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.'
    unless $ENV{TEST_AUTHOR};

my %opt;
my $rc_file = File::Spec->catfile($Bin, 'perlcriticrc');
$opt{'-profile'} = $rc_file if -r $rc_file;

if (Perl::Critic->require('1.078') &&
    Test::Perl::Critic->require &&
    Test::Perl::Critic->import(%opt)) {

    all_critic_ok("blib");
} else {
    plan skip_all => $@;
}
    
