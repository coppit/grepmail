#include <stdio.h>
#include <string.h>
#include "fastreader.h"

#define DEBUG 0

char *_find_next_header(char* buffer);
int _ends_with_include(char *email);

static int BUFFER_SIZE_INCREMENT=1000000;
static int BUFFER_SIZE=0;

/* The current line count */
static long LINE = 1;

/* The last line read */
static char LAST_LINE[256];

/* Storage for the email */
static char *EMAIL_BUFFER = NULL;

static unsigned int LENGTH_OF_EMAIL = 0;


int read_email(FILE *file_handle,char **email,long *email_line)
{
  char next_line[256];

  if (feof(file_handle))
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"eof, and no more buffered data\n");
#endif
    reset_line();
    return 0;
  }

  /* Allocate the memory if it hasn't been already. */
  if (LINE == 0)
  {
    fgets(LAST_LINE,255,file_handle);
    LINE = 1;
  }

  if (EMAIL_BUFFER == NULL)
  {
    BUFFER_SIZE = BUFFER_SIZE_INCREMENT;
    EMAIL_BUFFER = (char *)malloc((BUFFER_SIZE)*sizeof(char));
  }

  LENGTH_OF_EMAIL = 0;
  EMAIL_BUFFER[LENGTH_OF_EMAIL] = '\0';

  strcpy(EMAIL_BUFFER,LAST_LINE);
  LENGTH_OF_EMAIL += strlen(LAST_LINE);

  *email = EMAIL_BUFFER;
  *email_line = LINE;

  while (1)
  {
#if DEBUG==3
  fprintf(stderr,".");
#endif
    fgets(next_line,255,file_handle);

    if (feof(file_handle))
    {
#if DEBUG==1
  fprintf(stderr,"hit eof\n");
#endif
      reset_line();
      return 1;
    }

    LINE++;

    if(next_line[0] == 'F' && next_line[1] == 'r' && next_line[2] == 'o' &&
       next_line[3] == 'm' && next_line[4] == ' ')
    {
      if(_ends_with_include(EMAIL_BUFFER))
      {
#if DEBUG==1
  fprintf(stderr,"found include\n");
#endif
        /* Extend the size of the buffer if necessary */
        if (BUFFER_SIZE < LENGTH_OF_EMAIL + 255)
        {
#if DEBUG==1
  fprintf(stderr,"extending\n");
#endif
          BUFFER_SIZE += BUFFER_SIZE_INCREMENT;
          EMAIL_BUFFER = (char *)realloc(EMAIL_BUFFER,BUFFER_SIZE*sizeof(char));
          *email = EMAIL_BUFFER;
        }

        strcpy(EMAIL_BUFFER+LENGTH_OF_EMAIL,next_line);
        LENGTH_OF_EMAIL += strlen(next_line);
      }
      else
      {
#if DEBUG==1
  fprintf(stderr,"found another email\n");
#endif
        strcpy(LAST_LINE,next_line);
        return 1;
      }
    }
    else
    {
      /* Extend the size of the buffer if necessary */
      if (BUFFER_SIZE < LENGTH_OF_EMAIL + 255)
      {
#if DEBUG==1
  fprintf(stderr,"extending\n");
#endif
        BUFFER_SIZE += BUFFER_SIZE_INCREMENT;
        EMAIL_BUFFER = (char *)realloc(EMAIL_BUFFER,BUFFER_SIZE*sizeof(char));
        *email = EMAIL_BUFFER;
      }

      strcpy(EMAIL_BUFFER+LENGTH_OF_EMAIL,next_line);
      LENGTH_OF_EMAIL += strlen(next_line);
    }
  }
}

void reset_line()
{
#if DEBUG==1 || DEBUG==2 || DEBUG==3
  fprintf(stderr,"resetting line number\n");
#endif
  LINE = 0;
}

int _ends_with_include(char *email)
{
  char *location;
  int newlines;

  location = strstr(email,"\n----- Begin Included Message -----\n");

  if (location == 0)
  {
    return 0;
  }

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 35,"\n");

  if (location[35+newlines] == '\0')
  {
    return 1;
  }

  location = strstr(email,"\n-----Original Message-----\n");

  if (location == 0)
  {
    return 0;
  }

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 27,"\n");

  if (location[27+newlines] == '\0')
  {
    return 1;
  }
  else
  {
    return 0;
  }
}
