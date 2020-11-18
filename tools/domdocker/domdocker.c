
/************************************************************************
 Nash!Com Docker Helper Utilities
  (c) 2019-2020 NashCom, Daniel Nashed mailto:nsh@nashcom.de
*************************************************************************/

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h> 
#include <sys/types.h>
#include <sys/stat.h>

#include <global.h>
#include <osmisc.h>
#include <addin.h>
#include <misc.h>
#include <idtable.h>
#include <nsfdb.h>
#include <nsfdata.h>
#include <osfile.h>
#include <ostime.h>
#include <osmem.h>
#include <nsferr.h>
#include <oserr.h>
#include <miscerr.h>
#include <ods.h>
#include <osenv.h>
#include <kfm.h>
#include <ns.h>
#include <stats.h>

#define CHAR_TAB    0x09
#define CHAR_LF     0x0a

#define MAX(A, B) ((A) > (B) ? (A) : (B))
#define MIN(A, B) ((A) < (B) ? (A) : (B))

WORD gVerbose = 0;

void dummy ()
{
  printf ("dummy");
}

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

STATUS WriteStats (DHANDLE hStats, DWORD dwStatsLen, FILE *fp)
{
  STATUS error = NOERROR;
  char   *p;
  
  if (!hStats) return 0;

  p = (char *) OSLockObject(hStats);
  if (!p) return 0;

  fwrite (p, dwStatsLen, 1, fp);
  
  OSUnlockObject(hStats);
 
  return(error);
}

STATUS LNPUBLIC CheckServerAndStats (char *ServerName, char *StatusFile, char *StatsFile)
{
  STATUS  error       = NOERROR;
  DHANDLE hTable      = NULLHANDLE;
  DWORD   dwIndex     = 0;
  DWORD   dwTableSize = 0;

  FILE   *fp     = NULL;
  char   StatusText[255] = {0};

  if (*StatusFile)
  {
    error = NSPingServer(ServerName, &dwIndex, NULLHANDLE);

    if (error)
    {
      AddInLogMessageText("domdocker: Server [%s] not responding (0x%x)", error, ServerName, error);
      sprintf (StatusText, "ERROR,%d", error);
    }
    else
    {
      sprintf (StatusText, "OK,%d", dwIndex);
    }

    fp = fopen (StatusFile, "w");
  
    if (fp)
    {
        fwrite (StatusText, strlen (StatusText), 1, fp);
        fclose (fp);
        fp = NULL;
    }
  }

  if (*StatsFile)
  {
    error = NSPingServer(ServerName, &dwIndex, NULLHANDLE);

    if (error)
    {
      AddInLogMessageText("domdocker: Server [%s] not responding (0x%x)", error, ServerName, error);
      sprintf (StatusText, "ERROR,%d", error);
    }
    else
    {
      sprintf (StatusText, "OK,%d", dwIndex);
    }

    fp = fopen (StatsFile, "w");
  
    if (NULL == fp)
    {
      goto close;
    }

    error = NSFGetServerStats(ServerName, NULL, NULL, &hTable, &dwTableSize);
    if (error)
    {
      goto close;
    }

    WriteStats (hTable, dwTableSize, fp);

    fclose (fp);
    fp = NULL;
  }

close:

  if (hTable)
  {
    OSMemFree (hTable);
    hTable = NULLHANDLE;
  }

  if (fp)
  {
    fclose (fp);
    fp = NULL;
  }

  return error;
}


STATUS LNPUBLIC AddInMain (HMODULE hResourceModule, int argc, char *argv[])
{
  STATUS error = NOERROR;
  char   ServerName[MAXUSERNAME+1] = {0};
  char   StatusFile[255]  = {0};
  char   StatsFile[255]   = {0};
  char   DataDir[255]     = {0};
  DWORD  Interval         = 0;

  TIMEDATE Now;
  TIMEDATE NextRun;

  char *param;
  int  a;

  DHANDLE    hOldStatusLine   = NULLHANDLE;
  DHANDLE    hStatusLineDesc  = NULLHANDLE;
  HMODULE    hMod             = NULLHANDLE;

  AddInQueryDefaults (&hMod, &hOldStatusLine);
  AddInDeleteStatusLine (hOldStatusLine);

  hStatusLineDesc = AddInCreateStatusLine("domdocker");
  AddInSetDefaults (hMod, hStatusLineDesc);
  AddInSetStatusText("Running");

  OSGetDataDirectory(DataDir);

  if (argc <= 1)
  {   
    AddInLogMessageText("domdocker: No Parameters specified", 0, "");

    AddInLogMessageText("domdocker: Syntax", 0, "");
    AddInLogMessageText("domdocker: -status   [filename]", 0, "");
    AddInLogMessageText("domdocker: -stats    [filename]", 0, "");
    AddInLogMessageText("domdocker: -interval [sec]", 0, "");

    goto close;
  }

  for (a=1; a<argc; a++)
  {
    if (strcmp (argv[a], "-verbose") == 0)
    {
      gVerbose = 1;
    }
    else if (strcmp (argv[a], "-v") == 0)
    {
      gVerbose = 1;
    }

    else if (strcmp (argv[a], "-status") == 0)
    {
      if (a < (argc-1))
      {
        a++;
        param = argv[a];
        if (*param == '-') goto invalid_syntax;
  
        if (*param)
        {
          strdncpy (StatusFile, param, sizeof (StatusFile));
        }
      }
    }

    else if (strcmp (argv[a], "-stats") == 0)
    {
      if (a < (argc-1))
      {
        a++;
        param = argv[a];
        if (*param == '-') goto invalid_syntax;
  
        if (*param)
        {
          strdncpy (StatsFile, param, sizeof (StatsFile));
        }
      }
    }

    else if (strcmp (argv[a], "-server") == 0)
    {
      if (a < (argc-1))
      {
        a++;
        param = argv[a];
        if (*param == '-') goto invalid_syntax;
  
        if (*param)
        {
          strdncpy (ServerName, param, sizeof (ServerName));
        }
      }
    }

    else if (strcmp (argv[a], "-interval") == 0)
    {
      if (a < (argc-1))
      {
        a++;
        param = argv[a];
        if (*param == '-') goto invalid_syntax;
  
        if (*param)
        {
          Interval = 60 * atoi(param);
        }
      }
    }

    else
    {
      goto invalid_syntax;
    }
  
  } // for

  if ('\0' == *ServerName)
  {
    error = SECKFMGetUserName(ServerName);
    
    if (error)
    {
      AddInLogMessageText("domdocker:Error getting ServerName", error);
      goto close;
    }
  }

  if (Interval)
  {
    OSCurrentTIMEDATE(&NextRun);

    while (FALSE == AddInIdleDelay(1000))
    {
      OSCurrentTIMEDATE(&Now);

      if (TimeDateDifference (&Now, &NextRun) > 0)
      {
        OSCurrentTIMEDATE(&NextRun);
        TimeDateAdjust(&NextRun, 0, Interval, 0, 0, 0,0);

        CheckServerAndStats (ServerName, StatusFile, StatsFile);
      }
    } /* while */
  }
  else
  {
    CheckServerAndStats (ServerName, StatusFile, StatsFile);
  }

close:

  return error;

invalid_syntax:

  AddInLogMessageText("domdocker: Invalid Parameter specified [%s]", 0, argv[a]);

  return error;
}
