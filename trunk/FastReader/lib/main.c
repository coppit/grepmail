#include <stdio.h>

extern void reset_file(FILE *file_pointer);
extern int read_email(char **email,long *email_line);

int main(int argc, char**argv)
{
  int i;
  FILE *infile;
  char *email;
  char testfile[] = "../t/mailarc-1.txt";
  long line_number;

  if (argc == 1)
  {
    argv[1] = testfile;
    argc = 2;
  }

  for (i=1;i<argc;i++)
  {
    if (!(infile = fopen(argv[i], "r")))
    {
      fprintf (stderr, "can't open %s\n", argv[i]);
      return 1;
    }

    reset_file(infile);

    while (read_email(&email,&line_number)) 
    {
      printf("########\nLINE: %d\n%s########\n",line_number,email);
    }

    fclose(infile);
  }

  return 0;
}
