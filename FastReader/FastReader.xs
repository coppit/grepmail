#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

extern void reset_file(FILE *file_pointer);
extern int read_email(char **email,long *email_line);

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

static double
constant(char *name, int arg)
{
    errno = 0;
    switch (*name) {
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}


MODULE = Mail::Folder::FastReader		PACKAGE = Mail::Folder::FastReader		

PROTOTYPES: DISABLE

double
constant(name,arg)
	char *		name
	int		arg

void
read_email()
  INIT:
    char *email_arg;
    long email_line_arg;
    int result_arg;
  PPCODE:
    result_arg = read_email(&email_arg,&email_line_arg);

    # If the read was ok, return the status, email, and line as an array. See
    # EXAMPLE 5 of perlxstut (Perl 5.6 or later)
    if (result_arg == 1)
    {
      XPUSHs(sv_2mortal(newSVnv(result_arg)));
      # Let perl compute the length of the email
      XPUSHs(sv_2mortal(newSVpv(email_arg,0)));
      XPUSHs(sv_2mortal(newSVnv(email_line_arg)));
    }
    else
    {
      XPUSHs(sv_2mortal(newSVnv(result_arg)));
    }

void
reset_file(file_handle)
    FILE *file_handle
