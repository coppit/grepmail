#include <stdio.h>
#include <string.h>

#define DEBUG 0

char *_find_next_header(char* buffer);
int _ends_with_include(char *email,char *email_boundary);

/* Storage for the email */
static char *EMAIL_BUFFER = NULL;

/* Start of the email within buffer */
static char *START_OF_EMAIL = NULL;

/* The end of the current email and beginning of the next */
static char *EMAIL_BOUNDARY = NULL;

/* Amount to increase the buffer by when it fills up */
static unsigned int EMAIL_BUFFER_SIZE_INCREMENT=1000000;

/* The current size of the buffer */
static unsigned int EMAIL_BUFFER_SIZE = 0;

/* The amount to read at a time */
static unsigned int CHUNK_READ_SIZE = 255;

/* The end of the chunk that was last read */
static char *END_OF_CHUNK = NULL;

/* The current line count */
static long LINE_NUMBER = 0;

/* The file pointer */
static FILE *FILE_HANDLE;

/**************************************************************************/

/* Read one email from the file, setting *email to point to it, and
 * email_line to the line in the file on which it appears */

int read_email(char **email,long *email_line)
{
  char *read_pointer;

  /* Can't read from the end of the file */
  if (feof(FILE_HANDLE))
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"eof, and no more buffered data\n");
#endif
    return 0;
  }

  /* If this is the first email, pre-load the email buffer. Otherwise set
   * the null character back to the 'F' (from "From " that was read
   * before). */
  if (LINE_NUMBER == 0)
  {
    fgets(EMAIL_BUFFER,CHUNK_READ_SIZE,FILE_HANDLE);
    END_OF_CHUNK = strchr(EMAIL_BUFFER,'\0');
    START_OF_EMAIL = EMAIL_BUFFER;
  }
  else
  {
    *EMAIL_BOUNDARY = 'F';
    START_OF_EMAIL = EMAIL_BOUNDARY;
  }

  LINE_NUMBER++;

  /* Set the email and line number to return */
  *email = START_OF_EMAIL;
  *email_line = LINE_NUMBER;

  /* Keep reading lines until we hit the next email or EOF. When we
   * start, we have 1 line of the email in the buffer. */
  while (1)
  {
#if DEBUG==3
    fprintf(stderr,".");
#endif

    /* If the buffer is full, move the email down to the beginning of
     * the buffer */
    if (EMAIL_BUFFER + EMAIL_BUFFER_SIZE < END_OF_CHUNK + CHUNK_READ_SIZE)
    {
#if DEBUG==1
      fprintf(stderr,"Moving down email\n");
#endif
      memmove(EMAIL_BUFFER,START_OF_EMAIL,END_OF_CHUNK - START_OF_EMAIL);
      END_OF_CHUNK = END_OF_CHUNK - START_OF_EMAIL + EMAIL_BUFFER;
      START_OF_EMAIL = EMAIL_BUFFER;
      *email = START_OF_EMAIL;
    }

    /* Extend the size of the buffer if necessary to accommodate 1 more
     * line. */
    if (EMAIL_BUFFER + EMAIL_BUFFER_SIZE < EMAIL_BOUNDARY + CHUNK_READ_SIZE)
    {
#if DEBUG==1
      fprintf(stderr,"extending email buffer %u\n",EMAIL_BUFFER_SIZE);
#endif
      EMAIL_BUFFER_SIZE += EMAIL_BUFFER_SIZE_INCREMENT;
      EMAIL_BUFFER =
        (char *)realloc(EMAIL_BUFFER,EMAIL_BUFFER_SIZE*sizeof(char));
      END_OF_CHUNK = END_OF_CHUNK - START_OF_EMAIL + EMAIL_BUFFER;
      START_OF_EMAIL = EMAIL_BUFFER;
      *email = START_OF_EMAIL;
    }

    /* Read a line from the file and store it in the email buffer.  We
     * will replace the start of the line with a null if it turns out
     * to be the start of the next email. */
    read_pointer = fgets(END_OF_CHUNK,CHUNK_READ_SIZE,FILE_HANDLE);

    /* If we hit the end of the file, return the email */
    if (read_pointer == NULL)
    {
#if DEBUG==1
      fprintf(stderr,"hit eof\n");
#endif

      return 1;
    }

    EMAIL_BOUNDARY = END_OF_CHUNK;
    END_OF_CHUNK = strchr(END_OF_CHUNK,'\0');

    /* See if the line is the start of a new email, and the email
     * we've read so far doesn't end with an include message. */
    if(EMAIL_BOUNDARY[0] == 'F' && EMAIL_BOUNDARY[1] == 'r' &&
       EMAIL_BOUNDARY[2] == 'o' && EMAIL_BOUNDARY[3] == 'm' &&
       EMAIL_BOUNDARY[4] == ' ' &&
       !_ends_with_include(EMAIL_BOUNDARY-255,EMAIL_BOUNDARY))
    {
#if DEBUG==1
      fprintf(stderr,"found next email\n");
#endif

      *EMAIL_BOUNDARY = '\0';
      return 1;
    }
    else
    {
      LINE_NUMBER++;
    }
  }
}

/**************************************************************************/

void reset_file(FILE *infile)
{
#if DEBUG==1 || DEBUG==2 || DEBUG==3
  fprintf(stderr,"resetting line number\n");
#endif

  /* Initialize the email buffer if it has not been initialized already. */
  if (EMAIL_BUFFER == NULL)
  {
    EMAIL_BUFFER_SIZE = EMAIL_BUFFER_SIZE_INCREMENT;
    EMAIL_BUFFER = (char *)malloc((EMAIL_BUFFER_SIZE)*sizeof(char));
  }

  START_OF_EMAIL = EMAIL_BUFFER;

  FILE_HANDLE = infile;
  LINE_NUMBER = 0;
}

/**************************************************************************/

int _ends_with_include(char *email,char *email_boundary)
{
  char *location;
  int newlines;


  location = strstr(email,"\n----- Begin Included Message -----\n");

  if (location == 0)
    return 0;

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 35,"\n");

  if(location+35+newlines == email_boundary)
    return 1;


  location = strstr(email,"\n-----Original Message-----\n");

  if (location == 0)
    return 0;

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 27,"\n");

  if(location+27+newlines == email_boundary)
    return 1;

  return 0;
}
