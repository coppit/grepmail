package Module::Install::PRIVATE::Update_Test_Version;

use strict;

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

      open TEST_CASE, $test_case_file
        or die "Couldn't open test case: $!";

      local $/ = undef;
      my $test_case_code = <TEST_CASE>;

      $test_case_code =~ s/^grepmail .*$/grepmail $version/m;

      close TEST_CASE;

      unlink $test_case_file;

      open TEST_CASE, ">$test_case_file"
        or die "Couldn't open test case for updating: $!";

      binmode TEST_CASE;

      print TEST_CASE $test_case_code;

      close TEST_CASE;

      last;
    }
  }

  die "Couldn't find version line in $file_with_version" unless $found;

  close SOURCE;
}

1;
