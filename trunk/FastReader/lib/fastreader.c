/*
 * The file reading and buffering code was adapted from GNU grep.
*/

#include <stdio.h>

// For stat()
#include <sys/stat.h>

// For memchr()
#include <string.h>

// For errno
#include <errno.h>
#ifndef errno
extern int errno;
#endif

// For malloc and realloc
#ifdef STDC_HEADERS
# include <stdlib.h>
#else
char *malloc ();
char *realloc ();
#endif

// Used in reset()
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

/* Unaligned base of buffer. */
static char *unaligned_buffer_base;

/* Aligned base of buffer. */
static char *aligned_buffer_base;

/* Allocated size of buffer save region. */
static size_t save_region_size;

/* Total buffer size. */
static size_t buffer_total_size;

/* Preferred value of buffer_total_size / save_region_size.  */
#define PREFERRED_SAVE_FACTOR 5

/* alignment of memory pages */
static size_t pagesize;

/* Read offset; defined on regular files. */
static off_t buffer_offset;

/* residue is the portion of an email that is at the end. */
static size_t residue;

/* save is the number of bytes that need to be kept in the buffer when
 * the buffer is filled. */
static size_t save;

/* The name of the program, for error messages. */
static char program_name[] = "grepmail";

/* The current line number in the file. */
static long line_number = 1;

/* Beginning of user-visible stuff. */
static char *buffer_begin;

/* Limit of user-visible stuff. */
static char *buffer_end;

/* demarcate the beginning and end of viable emails in the buffer. */
static char *beginning_of_the_email = 0;
static char *end_of_the_email = 0;

/* store the character for the start of the next email */
static char start_char;

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

/* Read new stuff into the buffer, saving the specified
   amount of old stuff.  When we're done, 'buffer_begin' points
   to the beginning of the buffer contents, and 'buffer_end'
   points just after the end. */
static void
fill_buffer (size_t save, FILE* file)
{
  size_t fillsize = 0;
  size_t readsize;
  struct stat file_stat;
  size_t saved_offset;

  if (fstat (fileno(file), &file_stat) != 0)
  {
    error ("fstat", errno);
    return;
  }

  /* Offset from start of unaligned buffer to start of old stuff
     that we want to save.  */
  saved_offset = buffer_end - unaligned_buffer_base - save;

  if (save_region_size < save)
  {
    size_t aligned_save = ALIGN_TO (save, pagesize);
    size_t maxalloc = (size_t) -1;
    size_t newalloc;

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

    /* Grow save_region_size until it is at least as great as `save'; but
    if there is an overflow, just grow it to the next page boundary.  */
    while (save_region_size < save)
      if (save_region_size < save_region_size * 2)
        save_region_size *= 2;
      else
      {
        save_region_size = aligned_save;
        break;
      }

    /* Grow the buffer size to be PREFERRED_SAVE_FACTOR times
    save_region_size....  */
    newalloc = PREFERRED_SAVE_FACTOR * save_region_size;
    if (maxalloc < newalloc)
    {
      /* ... except don't grow it more than a pagesize past the
         file size, as that might cause unnecessary memory
         exhaustion if the file is large.  */
      newalloc = maxalloc;
      save_region_size = aligned_save;
    }

    /* Check that the above calculations made progress, which might
    not occur if there is arithmetic overflow.  If there's no
    progress, or if the new buffer size is larger than the old
    and buffer reallocation fails, report memory exhaustion.  */
    if (save_region_size < save || newalloc < save
    || (newalloc == save && newalloc != maxalloc)
    || (buffer_total_size < newalloc
        && ! (aligned_buffer_base = page_alloc ((buffer_total_size = newalloc) + 1, &unaligned_buffer_base))))
      fatal (_("memory exhausted"), 0);
  }

  buffer_begin = aligned_buffer_base + save_region_size - save;
  memmove (buffer_begin, unaligned_buffer_base + saved_offset, save);
  readsize = buffer_total_size - save_region_size;

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
    while ((bytesread = read (fileno(file), aligned_buffer_base + save_region_size, readsize)) < 0
     && errno == EINTR)
      continue;
    if (bytesread >= 0)
      fillsize = bytesread;
  }

  buffer_offset += fillsize;
#if O_BINARY
  if (fillsize)
    fillsize = undossify_input (aligned_buffer_base + save_region_size, fillsize);
#endif
  buffer_end = aligned_buffer_base + save_region_size + fillsize;
}

/* ------------------------------------------------------------------------ */

/* Scan the specified portion of the buffer, matching lines (or
   between matching lines if OUT_INVERT is true).  Return a count of
   lines printed. */
static int
grepbuf (char *beg, char *lim)
{
  char old;

  old = *lim;
  *lim = '\0';


  *lim = old;
  return 0;
}

/* ------------------------------------------------------------------------ */

/* Reset the buffer for a new file, returning zero if we should skip it.
   Initialize on the first time through. */
static int
reset (FILE *file, char const *filename)
{
  struct stat file_stat;

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

  buffer_end = aligned_buffer_base;

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
  return 1;
}

/* ------------------------------------------------------------------------ */

/* Count the number of newlines in the buffer, adding this to totalnl
 */
static void
nlscan ()
{
    char *beg;

    for (beg = beginning_of_the_email;
        (beg = memchr (beg, '\n', end_of_the_email - beg));  beg++)
      line_number++;
}

/* ------------------------------------------------------------------------ */

int
read_email (char **email,long *email_line_number, FILE* file)
{
  /* Put the 'F' for the start of the next email back */
  if (end_of_the_email)
    *end_of_the_email = start_char;

  /* Try to read some more into the buffer. */
  if (buffer_end - buffer_begin != save)
  {
    fill_buffer(save, file);

  /* Advance the beginning of the emails */
    beginning_of_the_email = buffer_begin + save - residue;
  }

  if (buffer_end + 1 == end_of_the_email)
    return 0;

  /* Looking for end of email */
/*
  for (end_of_the_email = beginning_of_the_email+1;
       end_of_the_email <= buffer_end &&
         (end_of_the_email[-1] != '\n' ||
          end_of_the_email[0] != 'F' ||
          end_of_the_email[1] != 'r' ||
          end_of_the_email[2] != 'o' ||
          end_of_the_email[3] != 'm' ||
          end_of_the_email[4] != ' ');
       end_of_the_email++)
    ;
*/
  for (end_of_the_email = buffer_end;
       end_of_the_email > beginning_of_the_email &&
         end_of_the_email[-1] != '\n';
       --end_of_the_email)
    ;

  /* Save the residue that doesn't comprise a complete email */
  if (buffer_end - buffer_begin != save)
  {
    residue = buffer_end - end_of_the_email;
  }

  /* If we did find a complete email */
  if (beginning_of_the_email < end_of_the_email)
  {
    *email_line_number = line_number;
    nlscan();

    *email = beginning_of_the_email;
    start_char = *end_of_the_email;
    *end_of_the_email = 0;
  }

  /* Advance the beginning of the emails */
  beginning_of_the_email = end_of_the_email;

  /* Compute the part to save on the next buffer read */
  if (buffer_end - buffer_begin != save)
  {
    save = residue + end_of_the_email - beginning_of_the_email;
  }

  return 1;
}

/* ------------------------------------------------------------------------ */

int
main (int argc,char *argv[])
{
  FILE *infile;
  char *email;
  long email_line_number;
  struct stat file_stat;

//  char filename[] = "/home/dwc3q/scripts/grepmail/devel/t/big-4.txt";
//  char filename[] = "/home/david/software/grepmail/devel/t/big-4.txt";
  char filename[] = "foo.txt";

  if (!(infile = fopen(filename, "r")))
  {
    fprintf (stderr, "can't open %s\n", filename);
    exit(1);
  }

  /* Only need this if we're using multiple files and we don't read until the
   * end of each file.
   * */
//  reset_line();
//

  if (fstat (fileno(infile),&file_stat) != 0)
  {
    error ("fstat", errno);
    return 0;
  }

  /* reset the buffer and counters */
  if (!reset (infile, "file"))
    return 0;

  residue = 0;
  save = 0;

  /* Keep reading from the buffer and processing the data. */
  while (read_email(&email,&email_line_number,infile))
  {
    printf("########\nLINE: %d\n%s########\n",email_line_number,email);
  }

  return 0;
}
