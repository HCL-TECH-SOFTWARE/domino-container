/*
   JSON schema validation tool
   ---------------------------
   Copyright Nash!Com, Daniel Nashed 2022-2025 - APACHE 2.0 see LICENSE

   Syntax: %s file.json [schema.json] [pretty.json] -default uses the standard HCL OneTouch setup JSON schema located in Domino binary directory
 */

#include "stdio.h"
#include "stdlib.h"
#include "sys/types.h"
#include "sys/stat.h"
#include "fcntl.h"

#define RAPIDJSON_ASSERT /* Override assertions to ensure we don't terminate for logical errors */
#include "rapidjson/document.h"
#include "rapidjson/error/en.h"
#include "rapidjson/schema.h"
#include "rapidjson/filereadstream.h"
#include "rapidjson/stringbuffer.h"
#include "rapidjson/prettywriter.h"
#include "rapidjson/prettywriter.h"

using namespace rapidjson;

#define DOMINO_EXEC_DIR_ENV                    "Notes_ExecDirectory"
#define DOMINO_EXEC_DIR_PATH                   "/opt/hcl/domino/notes/latest/linux"
#define DOMINO_ONE_TOUCH_SCHMEA_NAME           "dominoOneTouchSetup.schema.json"
#define DEFAULT_DOMINO_ONE_TOUCH_SCHMEA_TAG    "-default"

#define CHECKJSON_STATUS_VALID                 0
#define CHECKJSON_STATUS_INVALID               1
#define CHECKJSON_STATUS_NOT_MATCHNING_SCHEMA  2
#define CHECKJSON_STATUS_FILE_ERROR            3
#define CHECKJSON_STATUS_OTHER_ERROR           4


bool IsNullStr (const char *pszStr)
{
    if (NULL == pszStr)
        return true;

    if ('\0' == *pszStr)
        return true;

    return false;
}


int ProcessJSON (const char *pszInfile, const char *pszSchema, const char *pszOutfile)
{
    /* required: pszInfile, returns: 0=OK, 1=JSON invalid, 2=JSON not validated according to schmea, 3=file error, 4=other error */

    int    ret        = 1; /* Assume error until OK */
    FILE   *fp        = NULL;
    FILE   *fpInfile  = NULL;
    struct stat fStat = {0};

    size_t FileBufferSize = 1024000; /* 1 MB */

    char  *pszBuffer         = NULL;
    char  szSchemaFile[1024] = {0};

    const char *pszBinDir    = NULL;
    const char *pszStr       = NULL;

    Document jDoc;
    Document jSchemaDoc;

    /* If -default is specified, try to find schema JSON file in Domino binary directory */

    if ((pszSchema) && (0 == strcmp (pszSchema, DEFAULT_DOMINO_ONE_TOUCH_SCHMEA_TAG)))
    {
        pszBinDir = (getenv (DOMINO_EXEC_DIR_ENV));

        if (pszBinDir)
        {
            snprintf (szSchemaFile, sizeof (szSchemaFile), "%s/%s", pszBinDir, DOMINO_ONE_TOUCH_SCHMEA_NAME);
        }
        else
            snprintf (szSchemaFile, sizeof (szSchemaFile), "%s/%s", DOMINO_EXEC_DIR_PATH, DOMINO_ONE_TOUCH_SCHMEA_NAME);

       if (0 == stat (szSchemaFile, &fStat))
       {
           if (S_ISREG (fStat.st_mode))
               pszSchema = szSchemaFile;
       }
    }

    /* Read and check JSON file first */
    if (IsNullStr (pszInfile))
    {
        fprintf (stderr, "No JSON file specified!\n");
        ret = CHECKJSON_STATUS_FILE_ERROR;
        goto Done;
    }

    if (0 == strcmp (pszInfile, "-"))
    {
        fpInfile = stdin;
    }
    else
    {
        fp = fopen (pszInfile, "r");

        if (NULL == fp)
        {
            perror ("Cannot open JSON file");
            ret = CHECKJSON_STATUS_FILE_ERROR;
            goto Done;
        }

        fpInfile = fp;
    }

    pszBuffer = (char *) malloc (FileBufferSize);

    if (NULL == pszBuffer)
    {
        perror ("Cannot allocate file buffer");
        ret = CHECKJSON_STATUS_OTHER_ERROR;
        goto Done;
    }

    {
        FileReadStream jDocStream (fpInfile, pszBuffer, FileBufferSize);
        jDoc.ParseStream (jDocStream);

        if (jDoc.HasParseError())
        {
            pszStr = GetParseError_En (jDoc.GetParseError());

            if (pszStr)
               fprintf (stderr, "JSON file parsing error, offset: %lu: %s\n", jDoc.GetErrorOffset(), pszStr);
            else
               fprintf (stderr, "Cannot parse JSON file\n");

            goto Done;
        }

        if (fp)
        {
            fclose (fp);
            fp = NULL;
        }
    }

    /* Read and check JSON schema file when specified */
    if (false == IsNullStr (pszSchema) && (strcmp (pszSchema, ".")))
    {
        fp = fopen (pszSchema, "r");

        if (NULL == fp)
        {
            perror ("Cannot open JSON schema file");
            ret = CHECKJSON_STATUS_FILE_ERROR;
            goto Done;
        }
        else
        {
            FileReadStream jSchemaStream (fp, pszBuffer, FileBufferSize);
            jSchemaDoc.ParseStream (jSchemaStream);

            if (jSchemaDoc.HasParseError())
            {
                pszStr = GetParseError_En (jSchemaDoc.GetParseError());
                if (pszStr)
                    fprintf (stderr, "JSON schema file parsing error, offset: %lu: %s\n", jSchemaDoc.GetErrorOffset(), pszStr);

                ret = CHECKJSON_STATUS_INVALID;
                goto Done;
            }

            fclose (fp);
            fp = NULL;
        }

        {
            /* Now that both JSON files are valid, check the schema */
            SchemaDocument  jSchema    (jSchemaDoc);
            SchemaValidator jValidator (jSchema);

            if (!jDoc.Accept (jValidator))
            {
                rapidjson::StringBuffer jStrBuf;
                jValidator.GetInvalidSchemaPointer().StringifyUriFragment (jStrBuf);

                fprintf (stderr, "Invalid schema: %s\n", jStrBuf.GetString());
                fprintf (stderr, "Invalid keyword: %s\n", jValidator.GetInvalidSchemaKeyword());

                jStrBuf.Clear();

                jValidator.GetInvalidDocumentPointer().StringifyUriFragment (jStrBuf);
                 fprintf (stderr, "Invalid document: %s\n", jStrBuf.GetString());

                ret = CHECKJSON_STATUS_NOT_MATCHNING_SCHEMA;
                goto Done;
            }

            if (jValidator.IsValid())
            {
                fprintf (stderr, "JSON file [%s] validated according to schema [%s]!\n", pszInfile, pszSchema);
                ret = CHECKJSON_STATUS_VALID;
            }
        }
    }

    /* Write output if specified */
    if (false == IsNullStr (pszOutfile))
    {
        size_t written = 0;
        size_t towrite = 0;

        StringBuffer sb;
        PrettyWriter<StringBuffer> writer (sb);

        jDoc.Accept (writer);

        const char *pJsonPrettyStr = sb.GetString();

        if (NULL == pJsonPrettyStr)
        {
            goto Done;
        }

        if (0 == strcmp (pszOutfile, "-"))
        {
            printf ("%s\n", pJsonPrettyStr);
            goto Done;
        }

        fp = fopen (pszOutfile, "wb");

        if (NULL == fp)
        {
            perror ("Cannot open output file");
            ret = CHECKJSON_STATUS_FILE_ERROR;
            goto Done;
        }

        towrite = strlen (pJsonPrettyStr);
        written = fwrite (pJsonPrettyStr, 1, towrite, fp);

        if (written != towrite)
        {
           fprintf (stderr, "File not completely written\n");
           ret = CHECKJSON_STATUS_FILE_ERROR;
           goto Done;
        }
    }

Done:

    if (pszBuffer)
    {
        free (pszBuffer);
        pszBuffer = NULL;
    }

    if (fp)
    {
        fclose (fp);
        fp = NULL;
    }

    return ret;
}


int main (int argc, char *argv[])
{
    int ret = CHECKJSON_STATUS_OTHER_ERROR;
    char *pszInfile  = NULL;
    char *pszSchema  = NULL;
    char *pszOutfile = NULL;

    if (argc < 2)
        goto InvalidSyntax;

    pszInfile = argv[1];

    if (argc > 2)
        pszSchema = argv[2];

    if (argc > 3)
        pszOutfile = argv[3];

    ret = ProcessJSON (pszInfile, pszSchema, pszOutfile);

    return ret;

InvalidSyntax:

    fprintf (stderr, "\nSyntax: %s file.json [schema.json] [pretty.json]\n\n", argv[0]);
    return ret;
}
