/*
 * This is a buggy implementation of fastreader that is based on
 * buffering code from GNU grep. It doesn't seem any faster than the
 * naive version I implemented, but I thought I'd check it in anyway
 * for posterity. This implementation seems to be returning emails
 * where the start is not a header. :(
 */

#include <stdio.h>

/* For stat() */
#include <sys/stat.h>

/* For memchr() */
#include <string.h>

/* For ssize_t */
#include <sys/types.h>

/* For errno */
#include <errno.h>
#ifndef errno
extern int errno;
#endif

/* For malloc and realloc */
#ifdef STDC_HEADERS
# include <stdlib.h>
#else
char *malloc ();
char *realloc ();
#endif

/* Used in reset_buffer() */
#undef MAX
#define MAX(A,B) ((A) > (B) ? (A) : (B))

/* If we (don't) have I18N.  */
/* glibc defines _ */
#ifndef _
# ifdef HAVE_LIBINTL_H
#  include <libintl.h>
#  ifndef _
#   define _(Str) gettext (Str)
#  endif
# else
#  define _(Str) (Str)
# endif
#endif

/* ------------------------------------------------------------------------ */

/* Some buffer management stuff */

/* Beginning of user-visible stuff. */
static char *start_readable_buffer = NULL;

/* Limit of user-visible stuff. */
static char *end_readable_buffer = NULL;

/* Unaligned base of buffer. */
static char *unaligned_buffer_base = NULL;

/* Aligned base of buffer. */
static char *aligned_buffer_base = NULL;

/* Allocated size of buffer save region. */
static size_t save_region_size = 0;

/* Total buffer size. */
static size_t buffer_total_size = 0;

/* Preferred value of buffer_total_size / save_region_size.  */
#define PREFERRED_SAVE_FACTOR 5

/* alignment of memory pages */
static size_t pagesize = 0;

/* Read offset; defined on regular files. */
static off_t buffer_offset = 0;

/* The number of bytes that need to be kept in the buffer when the buffer is
 * filled. */
static size_t amount_to_save = 0;

/* The name of the program, for error messages. */
static char program_name[] = "grepmail";

/* The current line number in the file. */
static long line_number = 1;

/* demarcate the beginning and end of viable emails in the buffer. */
static char *start_email = 0;
static char *end_email = 0;

/* store the character for the start of the next email */
static FILE *file_pointer = NULL;

/* ------------------------------------------------------------------------ */

/* Print a message and possibly an error string.  Remember
   that something awful happened. */
static void
error (const char *mesg, int errnum)
{
  if (errnum)
    fprintf (stderr, "%s: %s: %s\n", program_name, mesg, strerror (errnum));
  else
    fprintf (stderr, "%s: %s\n", program_name, mesg);
/*  errseen = 1;*/
}

/* ------------------------------------------------------------------------ */

/* Like error (), but die horribly after printing. */
void
fatal (const char *mesg, int errnum)
{
  error (mesg, errnum);
  exit (2);
}

/* ------------------------------------------------------------------------ */

/* Return VAL aligned to the next multiple of ALIGNMENT.  VAL can be
   an integer or a pointer.  Both args must be free of side effects.  */
#define ALIGN_TO(val, alignment) \
  ((size_t) (val) % (alignment) == 0 \
   ? (val) \
   : (val) + ((alignment) - (size_t) (val) % (alignment)))

/* ------------------------------------------------------------------------ */

/* Return the address of a page-aligned buffer of size SIZE,
   reallocating it from *UP.  Set *UP to the newly allocated (but
   possibly unaligned) buffer used to build the aligned buffer.  To
   free the buffer, free (*UP).  */
static char *
page_alloc (size_t size, char **up)
{
  size_t asize = size + pagesize - 1;
  if (size <= asize)
  {
    char *p = *up ? realloc (*up, asize) : malloc (asize);
    if (p)
    {
      *up = p;
      return ALIGN_TO (p, pagesize);
    }
  }
  return NULL;
}

/* ------------------------------------------------------------------------ */

static void
grow_save_region(size_t amount_to_save, FILE *file)
{
  size_t aligned_save = ALIGN_TO (amount_to_save, pagesize);
  size_t maxalloc = (size_t) -1;
  size_t newalloc;
  struct stat file_stat;

  if (fstat (fileno(file), &file_stat) != 0)
  {
    error ("fstat", errno);
    return;
  }

  if (S_ISREG (file_stat.st_mode))
  {
    /* Calculate an upper bound on how much memory we should allocate.
       We can't use ALIGN_TO here, since off_t might be longer than
       size_t.  Watch out for arithmetic overflow.  */
    off_t to_be_read = file_stat.st_size - buffer_offset;
    size_t slop = to_be_read % pagesize;
    off_t aligned_to_be_read = to_be_read + (slop ? pagesize - slop : 0);
    off_t maxalloc_off = aligned_save + aligned_to_be_read;
    if (0 <= maxalloc_off && maxalloc_off == (size_t) maxalloc_off)
      maxalloc = maxalloc_off;
  }

  /* Grow save_region_size until it is at least as great as
   * `amount_to_save'; but if there is an overflow, just grow it to
   * the next page boundary.  */
  while (save_region_size < amount_to_save)
    if (save_region_size < save_region_size * 2)
      save_region_size *= 2;
    else
    {
      save_region_size = aligned_save;
      break;
    }

  /* Grow the buffer size to be PREFERRED_SAVE_FACTOR times
   * save_region_size....  */
  newalloc = PREFERRED_SAVE_FACTOR * save_region_size;

  /* I had to put a cap on this because it was growing too fast
   * when we saved a lot of the buffer, and the maxalloc was too big. */
  if (newalloc > 50000)
  {
    newalloc = save_region_size;
    save_region_size = aligned_save;
  }

  /* See if we've hit the upper limit on how much we can allocate */
  if (maxalloc < newalloc)
  {
    /* ... except don't grow it more than a pagesize past the
     * file size, as that might cause unnecessary memory
     * exhaustion if the file is large.  */
    newalloc = maxalloc;
    save_region_size = aligned_save;
  }

  /* Check that the above calculations made progress, which might
   * not occur if there is arithmetic overflow.  If there's no
   * progress, or if the new buffer size is larger than the old
   * and buffer reallocation fails, report memory exhaustion.  */
  if (save_region_size < amount_to_save || newalloc < amount_to_save
  || (newalloc == amount_to_save && newalloc != maxalloc)
  || (buffer_total_size < newalloc
      && ! (aligned_buffer_base = page_alloc (
             (buffer_total_size = newalloc) + 1, &unaligned_buffer_base))))
    fatal (_("memory exhausted"), 0);
}

/* ------------------------------------------------------------------------ */

/* Reset the buffer for a new file, returning zero if we should skip it.
   Initialize on the first time through. */
static int
reset_buffer (FILE *file)
{
  struct stat file_stat;
  /* This was an argument. Not sure why we need it. */
  char filename[] = "filename";

  if (pagesize)
    save_region_size = ALIGN_TO (buffer_total_size / PREFERRED_SAVE_FACTOR, pagesize);
  else
  {
    size_t usize_buffer_save;
    pagesize = getpagesize ();
    if (pagesize == 0)
      abort ();
#ifndef save_region_size
    usize_buffer_save = MAX (8192, pagesize);
#else
    usize_buffer_save = save_region_size;
#endif
    save_region_size = ALIGN_TO (usize_buffer_save, pagesize);
    buffer_total_size = PREFERRED_SAVE_FACTOR * save_region_size;
    /* The 1 byte of overflow is a kludge for dfaexec(), which
       inserts a sentinel newline at the end of the buffer
       being searched.  There's gotta be a better way... */
    if (save_region_size < usize_buffer_save
        || buffer_total_size / PREFERRED_SAVE_FACTOR != save_region_size
        || buffer_total_size + 1 < buffer_total_size
        || ! (aligned_buffer_base = page_alloc (buffer_total_size + 1, &unaligned_buffer_base)))
      fatal (_("memory exhausted"), 0);
  }

  end_readable_buffer = aligned_buffer_base;

  if (fstat (fileno(file), &file_stat) != 0)
  {
    error ("fstat", errno);
    return 0;
  }
  if (S_ISREG (file_stat.st_mode))
  {
    if (filename)
      buffer_offset = 0;
    else
    {
      buffer_offset = lseek (fileno(file), 0, SEEK_CUR);
      if (buffer_offset < 0)
      {
        error ("lseek", errno);
        return 0;
      }
    }
#ifdef HAVE_MMAP
    initial_buffer_offset = buffer_offset;
    bufmapped = mmap_option && buffer_offset % pagesize == 0;
#endif
  }
  else
  {
#ifdef HAVE_MMAP
    bufmapped = 0;
#endif
  }

  amount_to_save = 0;

  return 1;
}

/* ------------------------------------------------------------------------ */

/* Count the number of newlines in the buffer, adding this to totalnl
 */
static int
number_of_newlines (char* start, char* end)
{
    char *beg;
    int num = 0;

    for (beg = start; (beg = memchr (beg, '\n', end - beg));  beg++)
      num++;
}

/* ------------------------------------------------------------------------ */

/* Read new stuff into the buffer, saving the specified
   amount of old stuff.  When we're done, 'start_readable_buffer' points
   to the beginning of the buffer contents, and 'end_readable_buffer'
   points just after the end. If there is nothing in the buffer to read,
   start_readable_buffer == end_readable_buffer */
static void
fill_buffer (size_t amount_to_save, FILE* file)
{
  /* Used for memory-mapped I/O */
  size_t fillsize = 0;
  /* Amount to read into buffer (after it is grown if necessary) */
  size_t readsize;
  struct stat file_stat;
  /* Pointer to portion to save */
  char *start_of_saved;

  if (fstat (fileno(file), &file_stat) != 0)
  {
    error ("fstat", errno);
    return;
  }

  start_of_saved = end_readable_buffer - amount_to_save;


  /* Grow the save region to hold the save amount, taking page alignment into
   * account */
  if (save_region_size < amount_to_save)
    grow_save_region(amount_to_save, file);


  start_readable_buffer =
    aligned_buffer_base + save_region_size - amount_to_save;
  memmove (start_readable_buffer, start_of_saved, amount_to_save);
  readsize = buffer_total_size - save_region_size;

/* In GNU grep, HAVE_MMAP is set by configure */
#if defined(HAVE_MMAP)
  if (bufmapped)
  {
    size_t mmapsize = readsize;

    /* Don't mmap past the end of the file; some hosts don't allow this.
    Use `read' on the last page.  */
    if (file_stat.st_size - buffer_offset < mmapsize)
    {
      mmapsize = file_stat.st_size - buffer_offset;
      mmapsize -= mmapsize % pagesize;
    }

    if (mmapsize
    && (mmap ((caddr_t) (aligned_buffer_base + save_region_size), mmapsize,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_FIXED,
        fileno(file), buffer_offset)
        != (caddr_t) -1))
    {
      /* Do not bother to use madvise with MADV_SEQUENTIAL or
         MADV_WILLNEED on the mmapped memory.  One might think it
         would help, but it slows us down about 30% on SunOS 4.1.  */
      fillsize = mmapsize;
    }
    else
    {
      /* Stop using mmap on this file.  Synchronize the file
         offset.  Do not warn about mmap failures.  On some hosts
         (e.g. Solaris 2.5) mmap can fail merely because some
         other process has an advisory read lock on the file.
         There's no point alarming the user about this misfeature.  */
      bufmapped = 0;
      if (buffer_offset != initial_buffer_offset
          && lseek (fileno(file), buffer_offset, SEEK_SET) < 0)
      {
        error ("lseek", errno);
      }
    }
  }
#endif /*HAVE_MMAP*/

  if (! fillsize)
  {
    ssize_t bytesread;
    while ((bytesread = read (fileno(file),
              aligned_buffer_base + save_region_size, readsize)) < 0
     && errno == EINTR)
      continue;
    if (bytesread >= 0)
      fillsize = bytesread;
  }

  buffer_offset += fillsize;
  end_readable_buffer = aligned_buffer_base + save_region_size + fillsize;
}

/* ------------------------------------------------------------------------ */
char *_find_next_header(FILE* file);

int
read_email (char **email,long *email_line_number)
{
  size_t read_result;
  char *location;
  char *end_of_buffer;
  char *temp;

  if (end_email == end_readable_buffer)
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"eof, and no more buffered data\n");
#endif
    line_number = 1;

    start_readable_buffer[0] = '\0';
    end_readable_buffer = start_readable_buffer;
    start_email = start_readable_buffer;
    end_email = start_readable_buffer;

    return 0;
  }

  /* If we inserted a null character at the end of the email, we need to undo
   * it */
  if (end_email != end_readable_buffer && end_email != NULL)
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
      fprintf(stderr,"restoring 'F' and moving start of email %p\n",end_email);
#endif
    *end_email = 'F';
    start_email = end_email;
  }

  end_email = NULL;

  /* Keep reading until we hit EOF or find the next email */
  location = _find_next_header(file_pointer);

  /* Found another email in the buffer */
  if (location != NULL)
  {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
    fprintf(stderr,"finished reading email. found another afterwards\n");
#endif
    end_email = location;
    *end_email = '\0';

    *email = start_email;
    *email_line_number = line_number;

    for(temp=start_email;temp <= end_email;temp++)
    { 
      if (temp[0] == '\n')
      {
        line_number++;
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
    end_email = end_readable_buffer;
    *end_email = '\0';

    *email = start_email;
    *email_line_number = line_number;

    return 1;
  }
}

/* ------------------------------------------------------------------------ */

int _ends_with_include(char *start, char *end);

char *_find_next_header(FILE* file)
{
  /* Begin searching after first character of email buffer */
  int search_index = 1;
  long amount_to_save = 0;

  /* Read something into the buffer if we haven't already */
  if (start_email == NULL)
  {
    fill_buffer (0, file);
    start_email = start_readable_buffer;

    /* If we weren't able to read any new stuff, then return NULL because we */
    /* couldn't find the next email's header */
    if (start_readable_buffer == end_readable_buffer)
      return NULL;
  }
  /* Otherwise zero out the \n before the current location so we don't match */
  /* ourselves */
  else
  {
    start_email[-1] = '\0';
  }

  while (1)
  {
    /* If we run off the end of the buffer, then read in some more and keep */
    /* going */
    if (start_email + search_index + 4 >= end_readable_buffer)
    {
      amount_to_save = end_readable_buffer - start_email;
      fill_buffer (amount_to_save, file);
      start_email = start_readable_buffer;

      /* If we weren't able to read any new stuff, then return NULL because we */
      /* couldn't find the next email's header */
      if (end_readable_buffer - start_readable_buffer == amount_to_save)
        return NULL;
    }

    /* If we have a match, then return the location of the next email
     * */
    if (start_email[search_index - 1] == '\n' &&
        start_email[search_index + 0] == 'F' &&
        start_email[search_index + 1] == 'r' &&
        start_email[search_index + 2] == 'o' &&
        start_email[search_index + 3] == 'm' &&
        start_email[search_index + 4] == ' ' &&
        !_ends_with_include(start_email, start_email + search_index))
    {
#if DEBUG==1 || DEBUG==2 || DEBUG==3
      fprintf(stderr,"next header found\n");
#endif
      return start_email + search_index;
    }

    search_index++;
  }
}

/* ------------------------------------------------------------------------ */

int _ends_with_include(char *start, char *end)
{
  char temp_char;
  char *location;
  int newlines;

  temp_char = *end;
  *end = '\0';

  location = strstr(start,"\n----- Begin Included Message -----\n");

  if (location == NULL)
  {
    *end = temp_char;
    return 0;
  }

  /* Find the last newline after the begin included message */
  newlines = strspn(location + 35,"\n");

  if (location[35 + newlines] == '\0')
  {
    *end = temp_char;
    return 1;
  }
  else
  {
    *end = temp_char;
    return 0;
  }
}

/* ------------------------------------------------------------------------ */

void reset_file(FILE *infile)
{
  start_readable_buffer = NULL;
  end_readable_buffer = NULL;
  unaligned_buffer_base = NULL;
  aligned_buffer_base = NULL;
  save_region_size = 0;
  buffer_total_size = 0;
  pagesize = 0;
  buffer_offset = 0;
  amount_to_save = 0;
  start_email = 0;
  end_email = 0;
  file_pointer = infile;
  line_number = 1;

  reset_buffer(infile);
}
