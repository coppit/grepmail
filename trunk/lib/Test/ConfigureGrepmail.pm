package Test::ConfigureGrepmail;

use strict;

sub Set_Caching_And_Grep
{
  my $filename = shift;
  my $enable_caching = shift;
  my $enable_grep = shift;

  my $code = _Read_Code($filename);

  $code =~ s/^\$USE_CACHING = (\d+);/\$USE_CACHING = $enable_caching;/m;
  $code =~ s/^\$USE_GREP = (\d+);/\$USE_GREP = $enable_grep;/m;

  _Write_Code($filename, $code);
}

# --------------------------------------------------------------------------

sub Set_Cache_File
{
  my $filename = shift;
  my $cache_file = shift;

  my $code = _Read_Code($filename);

# Pre-5.10 versions of grepmail don't use MessageParser
=for nobody
  if ($code =~ /(Mail::Mbox::MessageParser::SETUP_CACHE\( {.*?} *\))/s)
  {
    my $original_cache_setup = $1;
    my $new_cache_setup = $original_cache_setup;

    $new_cache_setup =~ s/('file_name'\s*=>\s*)".*?"/$1"$cache_file"/;

    $code =~ s/\Q$original_cache_setup\E/$new_cache_setup/;
  }
=cut
  $code =~ s/('file_name'\s*=>\s*)".*?grepmail-cache"/$1"$cache_file"/;

  _Write_Code($filename, $code);
}

# --------------------------------------------------------------------------

sub _Read_Code
{
  my $filename = shift;

  local $/ = undef;

  open SOURCE, $filename
    or die "Couldn't open grepmail file \"$filename\": $!";
  my $code = <SOURCE>;
  close SOURCE;

  return $code;
}

# --------------------------------------------------------------------------

sub _Write_Code
{
  my $filename = shift;
  my $code = shift;

  open SOURCE, ">$filename"
    or die "Couldn't open grepmail file \"$filename\": $!";
  print SOURCE $code;
  close SOURCE;
}

1;
