#include <stdio.h>
#include "fastreader.h"

int main(int argc, char**argv)
{
  FILE *infile;
  char *email;
  long line_number;

  if (!(infile = fopen(argv[1], "r")))
  {
    fprintf (stderr, "can't open %s\n", argv[1]);
    return 1;
  }
/*
  if (!(infile = fopen("../t/mailarc-1.txt", "r")))
  {
    fprintf (stderr, "can't open ../t/mailarc-1.txt\n", argv[1]);
    return 1;
  }
*/

  /* Only need this if we're using multiple files and we don't read until the
   * end of each file.
   * */
  reset_line();

  while (read_email(infile,&email,&line_number)) 
  {
    printf("########\nLINE: %d\n%s########\n",line_number,email);
  }

  return 0;
}