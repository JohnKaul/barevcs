//===---------------------------------------------------*- C -*---===
// File Last Updated: 01.22.26 15:15:36
//
//: md2txt
//
// BY  : John Kaul [john.kaul@outlook.com]
//
// DESCRIPTION
// This is a project to convert simple markdown to text format.
//===-------------------------------------------------------------===

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdarg.h>

//-------------------------------------------------------------------
// Function Prototypes
//-------------------------------------------------------------------
static void *processfd(int arg);                               /* Open the FD and send to processline(); */
static void processline(char *str);                            /* Process one line of text at a time
                                                                  from the input file. */
static void processnested(const char *str);
static int readline(int fd, char *buf, int nbytes);            /* Read a line of text from file. */
static int cimemcmp(const void *s1, const void *s2, size_t n); /* case independent memory regon compare */
static int read_until(const char **src, char delim, char *dst, size_t dstcap);

//-------------------------------------------------------------------
// Global Variables
//-------------------------------------------------------------------
int filedescriptors[1];                                 /* An array to hold open file descriptors. */
int codeblock       = 0;                                /* Used for middle of codeblock. */
int listblock       = 0;                                /* Used for list blocks. */
int commentflag     = 0;                                /* Used for comment blocks (HTML style <!-- comment --> */

/**
 * printussage --
 *      Prints the usage string.
 */
static void printusage(char *str) { /*{{{*/
  fprintf(stdout, "**** Usage: %s <markdownfile>\n", str);
}
/*}}}*/

/**
 * processfd --
 *      Read lines from a given filedescritor and pass them to the
 *      `processline` function.
 */
static void *processfd(int arg) { /*{{{*/
  char buff[LINE_MAX];
  int fd;
  ssize_t nbytes;

  fd = arg;
  for (;;) {
    if ((nbytes = readline(fd, buff, LINE_MAX)) <= 0)
      break;
    processline(buff);
  }
  return NULL;
}
/*}}}*/

/**
 * cimemcmp --
 *      Preform a case independent memory region compare.
 */
static int cimemcmp(const void *s1, const void *s2, size_t n) { /*{{{*/
  if (n != 0) {
    const unsigned char *p1 = s1, *p2 = s2;

    do {
      if ((*p1++ & ~' ') != (*p2++ & ~' '))
        return (*--p1 - *--p2);
    } while (--n != 0);
  }
  return (0);
}
/*}}}*/

/**
 * read_until --
 *      Read characters from *src into dst up to delim or NUL or capacity-1.
 *
 * NOTES:
 *  Advances *src to the character after the closing delim if found, otherwise
 *  advances *src to the terminating NUL. Always NUL-terminates dst.
 *
 * Parameters:
 *  src      -   Pointer to input pointer; advanced as characters are consumed.
 *  delim    -   Delimiter character to stop at (not copied).
 *  dst      -   Destination buffer for extracted token (NUL-terminated).
 *  dstcap   -   Capacity of dst in bytes.
 *
 * Returns 1 if delim was found and consumed (i.e., *src advanced past it), 0 otherwise.
 */
static int read_until(const char **src, char delim, char *dst, size_t dstcap) { /* {{{ */
    size_t i = 0;
    const char *p = *src;

    while (*p && *p != delim) {
        if (i + 1 < dstcap) {          /* leave room for NUL */
            dst[i++] = *p;
        }
        p++;
    }
    dst[i] = '\0';

    if (*p == delim) {
        p++;                           /* consume closing delim */
        *src = p;
        return 1;
    } else {
        *src = p;                      /* reached NUL */
        return 0;
    }
}
/* }}} */

/**
 * Sanitize --
 *      Allow only "white-listed" chars in string.
 */
static void sanitize(char *str, size_t n) {           /* {{{ */
  if(!str) return;
  static char ok_chars[] = "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "1234567890"
    " \f\t\n"
    ;
  const char *end = str + n;
  for (str += strspn(str, ok_chars); str != end;
       str += strspn(str, ok_chars)) {
    *str = ' ';
  }
}
/* }}} */

/**
 * processnested --
 *      Process inline (nested) tokens from string `s`.
 *
 * Parameters:
 *  s   -   String to parse
 */
static void processnested(const char *str) {             /* {{{ */
    const char *p = str;
    char tok[512];                                      /* Temporary token buffer capacity. */

    while (*p) {
        switch (*p) {
        case '*':                                       /* bold */
            p++;
            read_until(&p, '*', tok, sizeof(tok));
            fprintf(stdout, "%s", tok);
            break;

        case '_':                                       /* italic */
            p++;
            read_until(&p, '_', tok, sizeof(tok));
            fprintf(stdout, "%s", tok);
            break;

        case '`':                                       /* inline literal */
            p++;
            read_until(&p, '`', tok, sizeof(tok));
            fprintf(stdout, "%s", tok);
            break;

        case '^':                                       /* reference */
            p++;
            read_until(&p, '^', tok, sizeof(tok));
            fprintf(stdout, "%s", tok);
            break;

        case '\\':                                      /* escape: \x\ -> x (or consume next char if present) */
            p++;                                        /* eat backslash */
            if (*p && *p != '\\') {
                /* copy single character up to buffer limit */
                tok[0] = *p;
                tok[1] = '\0';
                p++; /* consume escaped char */
                if (*p == '\\') p++;                    /* eat backslash if found */
                fprintf(stdout, "%s", tok);
            } else if (*p == '\\') {
                /* literal backslash sequence "\\": output single backslash and consume */
                fprintf(stdout, "\\");
                p++;
            } else {
                /* dangling backslash at end: output it */
                fprintf(stdout, "\\");
            }
            break;

        default:
            /* regular character: write single char */
            fprintf(stdout, "%c", *p);
            p++;
            break;
        } /* switch */
    } /* while */
}
/* }}} */

/**
 * processline --
 *      This process the current line from the file and handles
 *      line-level constructs (leading tokens, block state--codeblock,
 *      listblock, etc.).
 *
 * Parameters:
 *  str -   string to search
 */
static void processline(char *str) { /*{{{*/
    int c;                                                /* Current character */
    c = *str;                                             /* Start at the beginning of the string */

    switch (c) {
//:~        case '\n':                                          // Newlines are replaced with a break.
//:~          fprintf(stdout, "\n");
//:~          break;

//:~        case 'a':                                           // Look for the string 'author:'
//:~          if(cimemcmp(str, "author:", 7) == 0) {
//:~            str += 7;                                       /* Eat the `author:` string. */
//:~            fprintf(stdout, "AUTHOR:%s", str);
//:~            break;
//:~          }

//:~        case 'd':                                           // Date
//:~          if(cimemcmp(str, "date:", 5) == 0) {
//:~            str += 5;                                       /* Eat the `date:` string */
//:~            fprintf(stdout, "DATE: %s", str);
//:~            break;
//:~          }

//:~        case 't':                                           // Look for the string 'title:'
//:~          if(cimemcmp(str, "title:", 6) == 0) {
//:~            str += 6;                                       /* Eat the `title:` string. */
//:~            fprintf(stdout, "TITLE: %s", str);
//:~            break;
//:~          }

      case '#':                                           // Section break (heading)
        if (*str++ == '#') {                              /* eat all the leading hashs. */
          while (*str != ' ' || *str == '\n') str++;
        }
        str++;
        sanitize(str, strlen(str));                       /* sanitize rest of string of all hashs */
//:~          fprintf(stdout, "***\n");
        fprintf(stdout, "%s", str);
//:~          fprintf(stdout, "***\n");
        break;


//      case '-':                                           // A list item or a single dash is a list terminator
//                                                          // EG: "-f" or "-f file" or just "-"
//        if(cimemcmp("-->", str, 3) == 0) {                /* First check if this is the end of a comment block */
//          commentflag = 0;
//          break;
//        }
//        if (*(str + 1) == '\n') break;
//        fprintf(stderr, "%s", str);
//        break;

      case '~':                                           // An alternate list terminator
        break;

//      case '<':                                           // The start of a `no format` section (this is also the
//                                                          // symbol used in vim's docformat).
//        if (cimemcmp("<!--", str, 4) == 0) {              /* Start of a comment block */
//          commentflag = 1;
//          break;
//        }
//        codeblock = 1;                                    /* Set the `codeblock` flag */
//        break;

      case '>':                                           // The end of a `no format` section
        codeblock = 0;
        break;

      case '`':                                           // Code block
        if(cimemcmp(str, "```", 3) == 0) {
          if(codeblock == 0) {                            /* Check to see if the `codeblock` flag has been set. */
            codeblock = 1;
          } else if (codeblock == 1) {
            codeblock = 0;
          }
          break;
        }

      default:
        if(commentflag == 1) {
          break;
        }

        // Move to the next character
        c++;

        if (codeblock == 0) {                             /* If we're not in a clode block... */
          processnested(str);                             /* Check the rest of the string for nested elements. */
        } else {                                          /* otherwise just print the line. */
          fprintf(stdout, "%s", str);
        }
        break;
    }
}
/*}}}*/

/**
 * readline --
 *      Reads a line from file descriptor and stores the string in buf.
 *
 * ARGS
 *  fd       -   file descriptor
 *  buf      -   where to store the string
 *  nbytes   -   How may bytes to read.
 *
 * RETURNS
 *  int
 */
static int readline(int fd, char *buf, int nbytes) { /*{{{*/
  int numread = 0;
  int returnval;

  while (numread < nbytes - 1) {
    returnval = read(fd, buf + numread, 1);
    if ((returnval == -1) && (errno == EINTR))
      continue;
    if ((returnval == 0) && (numread == 0))
      return 0;
    if (returnval == 0)
      break;
    if (returnval == -1)
      return -1;
    numread++;
    if (buf[numread - 1] == '\n') {
      buf[numread] = '\0';
      return numread;
    }
  }
  errno = EINVAL;
  return -1;
}
/*}}}*/

//------------------------------------------------------*- C -*------
// Main
//-------------------------------------------------------------------
int main(int argc, char *argv[]) {
    int fd = 0; /* default: stdin */
    if (argc > 2) {
        printusage(argv[0]);
        return 1;
    }
    if (argc == 2) {
        fd = open(argv[1], O_RDONLY);
        if (fd == -1) {
            fprintf(stderr, "Failed to open file %s: %s\n", argv[1], strerror(errno));
            return 1;
        }
    }
    processfd(fd);
    if (argc == 2) close(fd);
    return 0;
} ///:~
