#include <stdio.h>
#include <string.h>

/* This implementation reads chunks from the file instead of one line
 * at a time. This code is not any faster than the naive line-by-line
 * implementation. Why? Well, for one, the buffer gets traversed twice
 * this way --- once by the OS when it's reading the file, and once
 * by me when I'm looking for a "\nFrom ". It's much easier to let the
 * OS look for a newline within its fgets implementation... */

#define DEBUG 0

char *_find_next_header(char* buffer);
int _ends_with_include(char *email_boundary);

/* Storage for the email */
static char *EMAIL_BUFFER = NULL;

/* Start of the email within buffer */
static char *START_OF_EMAIL = NULL;

/* The end of the current email and beginning of the next */
static char *EMAIL_BOUNDARY = NULL;

/* Amount to increase the buffer by when it fills up */
static unsigned int EMAIL_BUFFER_SIZE_INCREMENT=8000;

/* The current size of the buffer */
static unsigned int EMAIL_BUFFER_SIZE = 0;

/* The amount to read at a time */
static unsigned int CHUNK_READ_SIZE = 3000;

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
  size_t amount_read;
  char *scan_location;
  char *old_email_buffer;

  /* Can't read from the end of the file and empty buffer */
  if (feof(FILE_HANDLE) && EMAIL_BOUNDARY == END_OF_CHUNK)
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
    amount_read = fread(EMAIL_BUFFER,sizeof(char),CHUNK_READ_SIZE,FILE_HANDLE);
    *(EMAIL_BUFFER+amount_read) = '\0';
    END_OF_CHUNK = EMAIL_BUFFER + amount_read;
    START_OF_EMAIL = EMAIL_BUFFER;
    EMAIL_BOUNDARY = START_OF_EMAIL;
  }
  else
  {
    *EMAIL_BOUNDARY = 'F';
    START_OF_EMAIL = EMAIL_BOUNDARY;
  }

  /* Set the email and line number to return */
  *email = START_OF_EMAIL;
  *email_line = LINE_NUMBER + 1;

  /* Keep reading lines until we hit the next email or EOF. When we
   * start, START_OF_EMAIL points to the start of the next email. */
  scan_location = EMAIL_BOUNDARY;
  while (1)
  {
#if DEBUG==3
    fprintf(stderr,".");
#endif

    if (*scan_location == '\n')
      LINE_NUMBER++;

    if(scan_location[0] == '\n' && scan_location[1] == 'F' &&
       scan_location[2] == 'r' && scan_location[3] == 'o' &&
       scan_location[4] == 'm' && scan_location[5] == ' ' &&
       !_ends_with_include(scan_location+1))
    {
#if DEBUG==1
      fprintf(stderr,"found next email\n");
#endif
      EMAIL_BOUNDARY = scan_location + 1;

      *EMAIL_BOUNDARY = '\0';
      return 1;
    }

    if (scan_location != END_OF_CHUNK)
    {
      scan_location++;
      continue;
    }

    scan_location--;

    /* If the buffer is full, and moving the email down to the
     * beginning of the buffer will free enough memory for a read, do
     * it */
    if (EMAIL_BUFFER + EMAIL_BUFFER_SIZE < END_OF_CHUNK + CHUNK_READ_SIZE &&
        START_OF_EMAIL - EMAIL_BUFFER >= CHUNK_READ_SIZE)
    {
#if DEBUG==1
      fprintf(stderr,"Moving down email\n");
#endif
      memmove(EMAIL_BUFFER,START_OF_EMAIL,END_OF_CHUNK - START_OF_EMAIL);
      END_OF_CHUNK += EMAIL_BUFFER - START_OF_EMAIL;
      scan_location += EMAIL_BUFFER - START_OF_EMAIL;
      START_OF_EMAIL = EMAIL_BUFFER;
      *email = START_OF_EMAIL;
    }

    /* Extend the size of the buffer if necessary to accommodate 1 more
     * chunk. */
    if (EMAIL_BUFFER + EMAIL_BUFFER_SIZE < END_OF_CHUNK + CHUNK_READ_SIZE)
    {
#if DEBUG==1
      fprintf(stderr,"extending email buffer %u\n",EMAIL_BUFFER_SIZE);
#endif
      EMAIL_BUFFER_SIZE += EMAIL_BUFFER_SIZE_INCREMENT;
      old_email_buffer = EMAIL_BUFFER;
      EMAIL_BUFFER =
        (char *)realloc(EMAIL_BUFFER,EMAIL_BUFFER_SIZE*sizeof(char));
      END_OF_CHUNK += EMAIL_BUFFER - old_email_buffer;
      scan_location += EMAIL_BUFFER - old_email_buffer;
      START_OF_EMAIL += EMAIL_BUFFER - old_email_buffer;
      *email = START_OF_EMAIL;
    }

    /* Read a line from the file and store it in the email buffer.  We
     * will replace the start of the line with a null if it turns out
     * to be the start of the next email. */
    amount_read = fread(END_OF_CHUNK,sizeof(char),CHUNK_READ_SIZE,FILE_HANDLE);
    *(END_OF_CHUNK+amount_read) = '\0';
    END_OF_CHUNK += amount_read;

    if (amount_read == 0)
    {
#if DEBUG==1
      fprintf(stderr,"hit eof\n");
#endif
      EMAIL_BOUNDARY = END_OF_CHUNK;

      return 1;
    }

    scan_location++;
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

int _ends_with_include(char *email_boundary)
{
  char *location;
  int newlines;

  location = strstr(email_boundary-255,"\n----- Begin Included Message -----\n");

  if (location == 0)
    return 0;

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 35,"\n");

  if(location+35+newlines == email_boundary)
    return 1;


  location = strstr(email_boundary-255,"\n-----Original Message-----\n");

  if (location == 0)
    return 0;

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 27,"\n");

  if(location+27+newlines == email_boundary)
    return 1;

  return 0;
}
