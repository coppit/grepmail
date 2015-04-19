package Module::Install::PRIVATE::Update_Test_Version;

use strict;
use File::Slurp;

use vars qw( @ISA $VERSION );

use Module::Install::Base;
@ISA = qw( Module::Install::Base );

$VERSION = sprintf "%d.%02d%02d", q/0.10.0/ =~ /(\d+)/g;

# ---------------------------------------------------------------------------

sub Update_Test_Version
{
  my $self = shift;
  my $file_with_version = shift;
  my $test_case_file = shift;

  open SOURCE, $file_with_version
    or die "Couldn't open grepmail file: $!";

  my $found = 0;

  while (my $line = <SOURCE>)
  {
    if ($line =~ /^\$VERSION = (.*q\/(.*?)\/.*);/)
    {
      $found = 1;

      my $version = eval $1;

      my $test_case_code = read_file($test_case_file);

      $test_case_code =~ s/^grepmail .*$/grepmail $version/m;

      unlink $test_case_file;

      write_file("$test_case_file", { binmode => ':raw' }, $test_case_code);

      last;
    }
  }

  die "Couldn't find version line in $file_with_version" unless $found;

  close SOURCE;
}

1;
