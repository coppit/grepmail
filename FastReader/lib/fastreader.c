/*
This version of fastreader.c tries to read from the file in chunks, saving
the slop in a buffer. It's slower and buggy, but I thought I would check it in
in case anyone wants to use the code as a starting point for something faster.
*/

#include <stdio.h>
#include <string.h>

#define DEBUG 0

char *_find_next_header(char* buffer);
int _ends_with_include(char *email);

/* Some constants. These are pretty fast settings on my machine. */
static int READ_CHUNK_SIZE=500000;
static int BUFFER_SIZE_INCREMENT=1000000;

/* The current line count */
static long LINE = 1;

/* We need to buffer the input because sometimes we're given a filehandle
 * which can't be seek'd. The END_OF_BUFFER is the end of the data that we've
 * read from the file handle. (END_OF_BUFFER - START_OF_BUFFER <= BUFFER_SIZE)
 * */
static long BUFFER_SIZE = 0;
static char *START_OF_BUFFER = NULL;
static char *END_OF_BUFFER = NULL;

/* Two pointers into the email buffer which indicate the start and end of the
 * email being returned
 */
static char *START_OF_EMAIL = NULL;
static char *END_OF_EMAIL = NULL;

static FILE *FILE_HANDLE;

int read_email(char **email,long *email_line)
{
  size_t read_result;
  char *location;
  char *end_of_buffer;
  char *temp;

  if (feof(FILE_HANDLE) && END_OF_EMAIL == END_OF_BUFFER)
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"eof, and no more buffered data\n");
#endif
    LINE = 1;

    START_OF_BUFFER[0] = '\0';
    END_OF_BUFFER = START_OF_BUFFER;
    START_OF_EMAIL = START_OF_BUFFER;
    END_OF_EMAIL = START_OF_BUFFER;

    return 0;
  }

  /* Allocate the memory if it hasn't been already. */
  if (START_OF_BUFFER == NULL)
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"allocating initial buffer\n");
#endif
    BUFFER_SIZE = BUFFER_SIZE_INCREMENT;
    START_OF_BUFFER = (char *)malloc((BUFFER_SIZE)*sizeof(char));
    START_OF_BUFFER[0] = '\0';
    END_OF_BUFFER = START_OF_BUFFER;
    START_OF_EMAIL = START_OF_BUFFER;
    END_OF_EMAIL = START_OF_BUFFER;
  }

  /* If we inserted a null character at the end of the email, we need to undo
   * it */
  if (END_OF_EMAIL != END_OF_BUFFER)
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
      fprintf(stderr,"restoring 'F' and moving start of email %p\n",END_OF_EMAIL);
#endif
    *END_OF_EMAIL = 'F';
    START_OF_EMAIL = END_OF_EMAIL;
  }

  END_OF_EMAIL = NULL;

  /* Keep reading until we hit EOF or find the next email */
  location = _find_next_header(START_OF_EMAIL);
  while (location == NULL && !feof(FILE_HANDLE))
  {
    /* First move the left-overs down */
    if (START_OF_EMAIL != START_OF_BUFFER)
    {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
      fprintf(stderr,"copying left-overs\n");
#endif
      strncpy(START_OF_BUFFER,START_OF_EMAIL,END_OF_BUFFER-START_OF_EMAIL);
      START_OF_EMAIL = START_OF_BUFFER;
      END_OF_BUFFER = START_OF_BUFFER+strlen(START_OF_BUFFER);
    }

    /* Extend the size of the buffer if necessary */
    if (BUFFER_SIZE < (END_OF_BUFFER - START_OF_BUFFER) + READ_CHUNK_SIZE + 1)
    {
      BUFFER_SIZE += BUFFER_SIZE_INCREMENT;
#if DEBUG==1 || DEBUG==2 || DEBUG==3
      fprintf(stderr,"extending partial email buffer. Size is %d\n",
          BUFFER_SIZE);
#endif
      START_OF_BUFFER =
        (char *)realloc(START_OF_BUFFER,BUFFER_SIZE*sizeof(char));
      START_OF_EMAIL = START_OF_BUFFER;
/*      END_OF_BUFFER = START_OF_BUFFER + strlen(START_OF_BUFFER);*/
    }

    /* Now read the new stuff into the buffer */
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"reading another chunk\n");
#endif
    read_result =
      fread(END_OF_BUFFER,sizeof(char),READ_CHUNK_SIZE,FILE_HANDLE);
    END_OF_BUFFER += read_result;
    *END_OF_BUFFER = '\0';

    location = _find_next_header(START_OF_EMAIL);
  }

  /* Found another email in the buffer */
  if (location != NULL)
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"finished reading email. found another afterwards\n");
#endif
    END_OF_EMAIL = location;
    *END_OF_EMAIL = '\0';

    *email = START_OF_EMAIL;
    *email_line = LINE;

    for(temp=START_OF_EMAIL;temp <= END_OF_EMAIL;temp++)
    { 
      if (temp[0] == '\n')
      {
        LINE++;
      }
    }

    return 1;
  }
  /* Hit EOF while reading email. Have the email point to whatever we read. */
  else
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"last email found\n");
#endif
    END_OF_EMAIL = END_OF_BUFFER;
    *END_OF_EMAIL = '\0';

    *email = START_OF_EMAIL;
    *email_line = LINE;

    return 1;
  }
}

void reset_file(FILE *infile)
{
#if DEBUG==1 || DEBUG==2 || DEBUG==3
  fprintf(stderr,"resetting line number\n");
#endif

  BUFFER_SIZE = 0;
  START_OF_BUFFER = NULL;
  END_OF_BUFFER = NULL;

  START_OF_EMAIL = NULL;
  END_OF_EMAIL = NULL;

  FILE_HANDLE=infile;

  LINE = 1;
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
  else
  {
    return 0;
  }
}

char *_find_next_header(char* buffer)
{
  int location = 0;
  char* search_location;

  search_location = strstr(buffer,"\nFrom ");
  while (search_location != NULL)
  {
    search_location[1] = 0;

    if (!_ends_with_include(buffer))
    {
      search_location[1] = 'F';
#if DEBUG==1 || DEBUG==2 || DEBUG==3
      fprintf(stderr,"next header found\n");
#endif
      return search_location + 1;
    }
    else
    {
      search_location[1] = 'F';
      search_location = strstr(search_location+1,"\nFrom ");
    }
  }

#if DEBUG==1 || DEBUG==2 || DEBUG==3
      fprintf(stderr,"next header not found\n");
#endif
  return NULL;
}
