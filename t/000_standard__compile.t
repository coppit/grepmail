#!perl -w

use strict;
use warnings;

BEGIN {
  if ($^O eq 'MSWin32') {
    use Test::More skip_all =>
        "Test::Compile doesn't work properly on Windows";
  } else {
    use Test::More;
    eval "use Test::Compile";
    Test::More->builder->BAIL_OUT(
        "Test::Compile required for testing compilation") if $@;
    all_pl_files_ok('blib/script/grepmail');
  }
}
    
