
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <global.h>
#include <addin.h>
#include <misc.h>
#include <stdio.h>
#include <intl.h>


#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>
#include <locale.h>
#include <langinfo.h>
#include <reg.h>



STATUS LNPUBLIC DumpIDInfo (const char *pszFilename)
{
    STATUS error = NOERROR;
    WORD   wLen = 0;
    char   szUsername[MAXUSERNAME+1] = {0};

    if (NULL == pszFilename)
    {
        error = SECKFMGetUserName (szUsername);

        if (error)
        {
            AddInLogMessageText ("Cannot get current username", error);
            goto Done;
        }
    }
    else
    {
        error = REGGetIDInfo ((char *)pszFilename, REGIDGetName, szUsername, sizeof(szUsername)-1, &wLen);

        if (error)
        {
            AddInLogMessageText ("Cannot get username for [%s]", error, pszFilename);
            goto Done;
        }

        szUsername[wLen] = '\0';
    }

    printf ("Username=%s\n", szUsername);

Done:

    return error;
}


STATUS LNPUBLIC DumpLangInfoItem (const char *pszLangItemConst, nl_item LangItemEnum)
{
    STATUS error = NOERROR;
    char *pLangInfo = NULL;

    pLangInfo = nl_langinfo (LangItemEnum);

    AddInLogMessageText ("OS.nl_langinfo [%s] : [%s]", 0, pszLangItemConst, pLangInfo);

    return error;
}


STATUS LNPUBLIC DumpLangInfoAll()
{
    STATUS error = NOERROR;

    AddInLogMessageText ("--- OS-Level nl_langinfo ---", 0, "");

    DumpLangInfoItem ("CODESET",   CODESET);
    DumpLangInfoItem ("D_T_FMT",   D_T_FMT);
    DumpLangInfoItem ("D_FMT",     D_FMT);
    DumpLangInfoItem ("T_FMT",     T_FMT);
    DumpLangInfoItem ("RADIXCHAR", RADIXCHAR);
    DumpLangInfoItem ("THOUSEP",   THOUSEP);
    DumpLangInfoItem ("YESEXPR",   YESEXPR);
    DumpLangInfoItem ("NOEXPR",    NOEXPR);
    DumpLangInfoItem ("CRNCYSTR",  CRNCYSTR);

    return error;
}


STATUS LNPUBLIC DumpLangOsLangStuff()
{
    STATUS error = NOERROR;
    char   *pLocale = NULL;
    char   szEnvVar[1024] = {0};

    struct lconv *pOsLocalSettings = NULL;

    AddInLogMessageText ("--- OS-Level other language information ---", 0, "");

    pLocale = getenv("LANG");

    if (pLocale == NULL)
    {
        strcpy (szEnvVar, "");
    }
    else
    {
        strcpy (szEnvVar, pLocale);
    }

    AddInLogMessageText ("OSEnvironment LANG: [%s]", 0, szEnvVar);

    pOsLocalSettings = localeconv();

    if (pOsLocalSettings)
    {
        AddInLogMessageText ("OS.localeconv decimal_point     : [%s]", 0, (pOsLocalSettings->decimal_point));
        AddInLogMessageText ("OS.localeconv thousands_sep     : [%s]", 0, (pOsLocalSettings->thousands_sep));
        AddInLogMessageText ("OS.localeconv currency_symbol   : [%s]", 0, (pOsLocalSettings->currency_symbol));
        AddInLogMessageText ("OS.localeconv mon_decimal_point : [%s]", 0, (pOsLocalSettings->mon_decimal_point));
        AddInLogMessageText ("OS.localeconv mon_thousands_sep : [%s]", 0, (pOsLocalSettings->mon_thousands_sep));
    }
    else
    {
        AddInLogMessageText ("localeconv() did not return information", 0, "");
    }

    return error;
}


STATUS LNPUBLIC DumpNotesIntlSettings ()
{
    STATUS error = NOERROR;
    INTLFORMAT IntlFormat = {0};

    AddInLogMessageText ("--- Notes International Settings ---", 0, "");

    OSGetIntlSettings (&IntlFormat, (WORD)sizeof (IntlFormat));

    AddInLogMessageText ("IntlFormat.Flags : %d", 0, IntlFormat.Flags);

    if (IntlFormat.Flags & CURRENCY_SUFFIX)     AddInLogMessageText ("%s", 0, "CURRENCY_SUFFIX");
    if (IntlFormat.Flags & CURRENCY_SPACE)      AddInLogMessageText ("%s", 0, "CURRENCY_SPACE");
    if (IntlFormat.Flags & NUMBER_LEADING_ZERO) AddInLogMessageText ("%s", 0, "NUMBER_LEADING_ZERO");
    if (IntlFormat.Flags & CLOCK_24_HOUR)       AddInLogMessageText ("%s", 0, "CLOCK_24_HOUR");
    if (IntlFormat.Flags & DAYLIGHT_SAVINGS)    AddInLogMessageText ("%s", 0, "DAYLIGHT_SAVINGS");
    if (IntlFormat.Flags & DATE_MDY)            AddInLogMessageText ("%s", 0, "DATE_MDY");
    if (IntlFormat.Flags & DATE_DMY)            AddInLogMessageText ("%s", 0, "DATE_DMY");
    if (IntlFormat.Flags & DATE_YMD)            AddInLogMessageText ("%s", 0, "DATE_YMD");
    if (IntlFormat.Flags & DATE_4DIGIT_YEAR)    AddInLogMessageText ("%s", 0, "DATE_4DIGIT_YEAR");

    AddInLogMessageText ("CurrencyDigits : %d", 0, IntlFormat.CurrencyDigits);
    AddInLogMessageText ("Length         : %d", 0, IntlFormat.Length);
    AddInLogMessageText ("TimeZone       : %d", 0, IntlFormat.TimeZone);

    AddInLogMessageText ("AMString       : [%s]", 0, IntlFormat.AMString);
    AddInLogMessageText ("PMString       : [%s]", 0, IntlFormat.PMString);

    AddInLogMessageText ("CurrencyString : [%s]", 0, IntlFormat.CurrencyString);
    AddInLogMessageText ("ThousandString : [%s]", 0, IntlFormat.ThousandString);
    AddInLogMessageText ("DecimalString  : [%s]", 0, IntlFormat.DecimalString);

    AddInLogMessageText ("DateString     : [%s]", 0, IntlFormat.DateString);
    AddInLogMessageText ("TimeString     : [%s]", 0, IntlFormat.TimeString);

    AddInLogMessageText ("YesterdayString: [%s]", 0, IntlFormat.YesterdayString);
    AddInLogMessageText ("TodayString    : [%s]", 0, IntlFormat.TodayString);
    AddInLogMessageText ("TomorrowString : [%s]", 0, IntlFormat.TomorrowString);

    return error;
}


int main (int argc, char *argv[])
{
    STATUS error = NOERROR;
    int  a = 0;
    char szBuild[MAXSPRINTF+1] = {0};

    error = NotesInitExtended (argc, argv);

    if (error)
    {
        printf ("C-API init error: %u", error);
        return error;
    }

    for (a=1; a<argc; a++)
    {
        if ('=' == *argv[a])
        {
            /* pass this directly to Domino for specifying the notes.ini */
        }

        else if (0 == strcmp (argv[a], "-intl"))
        {
            DumpLangInfoAll ();
            DumpLangOsLangStuff();
            error = DumpNotesIntlSettings();

            goto  Done;
        }

        else if (0 == strcmp (argv[a], "-idinfo"))
        {
            if (a<argc)
            {
		a++;
                error = DumpIDInfo (argv[a]);
	    }
            else
            {
                error = DumpIDInfo (NULL);
	    }
            goto  Done;
        }

        else
        {
            printf ("Invalid option [%s]\n", argv[a]);
            goto Done;
        }
    }

    /* by default print version if no other options beside the notes.ini are specified */
    AddInFormatError (szBuild, 1);
    printf ("DominoVersion=%s\n", szBuild);

Done:

    NotesTerm();
    return error;
}

