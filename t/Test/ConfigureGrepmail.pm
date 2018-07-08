package Test::ConfigureGrepmail;

use strict;
use File::Slurper qw(read_text write_text);

sub Set_Caching_And_Grep
{
  my $filename = shift;
  my $enable_caching = shift;
  my $enable_grep = shift;

  my $code = read_text($filename, undef, 1);

  $code =~ s/^\$USE_CACHING = (\d+);/\$USE_CACHING = $enable_caching;/m;
  $code =~ s/^\$USE_GREP = (\d+);/\$USE_GREP = $enable_grep;/m;

  write_text($filename, $code, undef, 1);
}

# --------------------------------------------------------------------------

sub Set_Cache_File
{
  my $filename = shift;
  my $cache_file = shift;

  my $code = read_text($filename, undef, 1);

  if ($code =~ /(Mail::Mbox::MessageParser::SETUP_CACHE\( {.*?} *\))/s)
  {
    my $original_cache_setup = $1;
    my $new_cache_setup = $original_cache_setup;

    $new_cache_setup =~ s/('file_name'\s*=>\s*)".*?"/$1"$cache_file"/;

    $code =~ s/\Q$original_cache_setup\E/$new_cache_setup/;
  }

  write_text($filename, $code, undef, 1);
}

1;
