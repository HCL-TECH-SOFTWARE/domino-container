
/*
############################################################################
# Copyright Nash!Com, Daniel Nashed 2020-2022 - APACHE 2.0 see LICENSE
############################################################################

  Helper tool to patch a /etc/passwd file for specifying specific uids for the 'notes' user.
  OpenShift has an own mechanism adding the uid to the /etc/passwd file.
  An alternate solution would be an init container adding the right user to the container.
*/

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>

#define MAX_TEXT_LINE 1000
#define MAX_LINES 1000

void strdncpy (char *s, const char *ct, size_t n)
{
  // copies string with a maximum of size_t chars from a null terminated string.
  // the result is always null terminated

  if (n>0)
  {
    strncpy (s, ct, n-1);
    s[n-1] = '\0';
  }
  else
  {
    s[0] = '\0';
  }
}

int strbegins (const char *str, const char *prefix)
{
  while(*prefix)
  {
    if(*prefix++ != *str++) return 0;
  }

  return 1;
}

int update_passwd_notes (const char *passwd_file, const char *uid_str, const char *homedir)
{
  FILE *fp   = NULL;
  int  count = 0;
  int  i     = 0;
  char line[MAX_LINES+1][MAX_TEXT_LINE+1] = {0};

  fp = fopen (passwd_file, "r");
  if (NULL == fp)
  {
    printf ("error -- canot open [%s] for reading\n", passwd_file);
    return 1;
  }

  while (fgets(line[count], MAX_TEXT_LINE, fp))
  {
    if (count >= MAX_LINES)
      break;
    count++;
  }

  fclose (fp);
  fp = NULL;

  fp = fopen (passwd_file, "w");
  if (NULL == fp)
  {
    printf ("error -- canot open [%s] for writing\n", passwd_file);
    return 1;
  }

  for (i=0; i<count; i++)
  {
    if (strbegins (line[i], "notes:"))
      fprintf (fp, "notes:x:%s:0::%s:/bin/bash\n", uid_str, homedir);
    else
      fprintf (fp, "%s", line[i]);
  }

  fclose (fp);
  fp = NULL;

  printf ("updated notes uid [%s] in [%s] \n", uid_str, passwd_file);
  return 0;
}

int main (int argc, char *argv[])
{
  int  ret = 0;
  char uid_str[255] = {0};

  if (argc > 1)
  {
    strdncpy (uid_str, argv[1], sizeof (uid_str));
  }
  else
  {
    return ret;
  }

  ret = update_passwd_notes ("/etc/passwd", uid_str, "/home/notes");

  return ret;
}
