#include <stdio.h>
#include <string.h>

#define DEBUG 0

char *_find_next_header(char* buffer);
int _ends_with_include(char *email,char *last_line);

static int BUFFER_SIZE_INCREMENT=1000000;
static int BUFFER_SIZE=0;

/* The current line count */
static long LINE = 0;

/* The last line read */
static char LAST_LINE[256];

/* Storage for the email */
static char *EMAIL_BUFFER = NULL;

static unsigned int LENGTH_OF_EMAIL = 0;

static FILE *FILE_HANDLE;

int read_email(char **email,long *email_line)
{
  char *start_of_new_line;

  /* Can't read from empty file */
  if (feof(FILE_HANDLE))
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"eof, and no more buffered data\n");
#endif
    LINE = 0;
    return 0;
  }

  /* Pre-load the LAST_LINE */
  if (LINE == 0)
    fgets(LAST_LINE,255,FILE_HANDLE);

  /* Copy the last line read during the previous run into the email
   * buffer */
  strcpy(EMAIL_BUFFER,LAST_LINE);
  LENGTH_OF_EMAIL = strlen(EMAIL_BUFFER);
  LINE++;

  /* Set the line number to return */
  *email_line = LINE;

  /* Keep reading lines until we hit the next email or EOF. At this
   * point we have 1 line of the email in the buffer. */
  while (1)
  {
#if DEBUG==3
    fprintf(stderr,".");
#endif

    /* Extend the size of the buffer if necessary to accomodate 1 more
     * line. */
    if (BUFFER_SIZE < LENGTH_OF_EMAIL + 255)
    {
#if DEBUG==1
      fprintf(stderr,"extending\n");
#endif
      BUFFER_SIZE += BUFFER_SIZE_INCREMENT;
      EMAIL_BUFFER = (char *)realloc(EMAIL_BUFFER,BUFFER_SIZE*sizeof(char));
    }

    /* Read a line from the file and store it at the end of the email
     * buffer. We will move it to LAST_LINE if it turns out to
     * be the start of the next email. */
    start_of_new_line = EMAIL_BUFFER+LENGTH_OF_EMAIL;
    fgets(start_of_new_line,255,FILE_HANDLE);
    LENGTH_OF_EMAIL += strlen(start_of_new_line);
    LINE++;

    /* If we hit the end of the file, return the email */
    if (feof(FILE_HANDLE))
    {
#if DEBUG==1
      fprintf(stderr,"hit eof\n");
#endif

      *email = EMAIL_BUFFER;
      return 1;
    }

    /* See if the line is the start of a new email. */
    if(start_of_new_line[0] == 'F' && start_of_new_line[1] == 'r' &&
       start_of_new_line[2] == 'o' && start_of_new_line[3] == 'm' &&
       start_of_new_line[4] == ' ')
    {
      /* If the email doesn't end with an included message declaration,
       * then the From line must be the start of a new email. */
      if(!_ends_with_include(start_of_new_line-255,start_of_new_line))
      {
#if DEBUG==1
  fprintf(stderr,"found next email\n");
#endif
        strncpy(LAST_LINE,start_of_new_line,255);
        LENGTH_OF_EMAIL -= strlen(start_of_new_line);
        *start_of_new_line = '\0';
        LINE--;

        *email = EMAIL_BUFFER;
        return 1;
      }
    }
  }
}

void reset_file(FILE *infile)
{
#if DEBUG==1 || DEBUG==2 || DEBUG==3
  fprintf(stderr,"resetting line number\n");
#endif

  /* Initialize the email buffer if it has not been initialized already. */
  if (EMAIL_BUFFER == NULL)
  {
    BUFFER_SIZE = BUFFER_SIZE_INCREMENT;
    EMAIL_BUFFER = (char *)malloc((BUFFER_SIZE)*sizeof(char));
  }

  FILE_HANDLE = infile;
  LINE = 0;
}

int _ends_with_include(char *email,char *last_line)
{
  char *location;
  int newlines;

  location = strstr(email,"\n----- Begin Included Message -----\n");

  if (location == 0)
    return 0;

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 35,"\n");

  if(location+35+newlines == last_line)
    return 1;

  location = strstr(email,"\n-----Original Message-----\n");

  if (location == 0)
    return 0;

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 27,"\n");

  if(location+27+newlines == last_line)
    return 1;
  else
    return 0;
}
