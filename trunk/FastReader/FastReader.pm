package Mail::Folder::FastReader;

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $AUTOLOAD);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
@EXPORT_OK = qw( reset_line read_email );
	
$VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.  If a constant is not found then control is passed
    # to the AUTOLOAD in AutoLoader.

    my $constname;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "& not defined" if $constname eq 'constant';
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
      if ($! =~ /Invalid/) {
        $AutoLoader::AUTOLOAD = $AUTOLOAD;
        goto &AutoLoader::AUTOLOAD;
      }
      else
      {
      	croak "Your vendor has not defined Mail::Folder::FastReader macro $constname";
      }
    }
    no strict 'refs';
    *$AUTOLOAD = sub () { $val };
    goto &$AUTOLOAD;
}

bootstrap Mail::Folder::FastReader $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

__END__

=head1 NAME

Mail::Folder::FastReader - A fast mailbox reader

=head1 SYNOPSIS

  use Mail::Folder::FastReader qw( read_email );

  open MAILBOX,"saved-mail";
  while (1)
  {
    my ($status, $email, $line_number) = read_email(MAILBOX);
    last unless $status

    print <<EOF;
EMAIL STARTING ON LINE $line_number:
$email
-------------------------------------
EOF
  }
  close MAILBOX;

=head1 DESCRIPTION

This module provides a simple and fast way to read unix-style mailboxes. It
basically searches for the next line that begins with "From ", but which
doesn't follow a "----- Begin Included Message -----".

=head2 FUNCTIONS

=over 4

=item ($status,$email,$line) = read_email(FILEHANDLE)

Read the next email from FILEHANDLE, storing the email in $email and the line
number in $line. The status is 1 if successful, and 0 if not.

=item reset_line()

Reset the internal line counter. You don't need to do this if you are only
reading from one file handle, or if you read to the end of one file handle
before starting to read from the next.

=head1 AUTHOR

David Coppit <david@coppit.org>

=head1 SEE ALSO

grepmail, mail(1), printmail(1), Mail::Internet(3)
Crocker,  D.  H., Standard for the Format of Arpa Internet Text Messages,
RFC822.

=cut
