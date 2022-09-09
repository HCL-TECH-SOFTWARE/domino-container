/*
   JSON schema validation tool
   ---------------------------
   Copyright Nash!Com, Daniel Nashed 2022 - APACHE 2.0 see LICENSE

   Syntax: %s file.json [schema.json] -default uses the standard HCL OneTouch setup JSON schema located in Domino binary directory
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

using namespace rapidjson;


#define DOMINO_EXEC_DIR_ENV                  "Notes_ExecDirectory"
#define DOMINO_EXEC_DIR_PATH                 "/opt/hcl/domino/notes/latest/linux"
#define DOMINO_ONE_TOUCH_SCHMEA_NAME         "dominoOneTouchSetup.schema.json"
#define DEFAULT_DOMINO_ONE_TOUCH_SCHMEA_TAG  "-default"


int validate_json (char *pszFile, char *pszSchema)
{
    /* required: pszFile, returns: 0=OK, 1=JSON invalid, 2=JSON not validated according to schmea, 3=file error */

    int   ret   = 1; /* Assume error until OK */
    FILE  *fp   = NULL;
    struct stat fStat = {0};

    char  szBuffer[0xFFFF]    = {0};
    char  szSchemaFile[1024]  = {0};

    const char *pSchema   = pszSchema;
    const char *pBinDir   = NULL;
    const char *pStr      = NULL;

    Document jDoc;
    Document jSchemaDoc;

    /* If -default is specified, try to find schema JSON file in Domino binary directory */

    if ((pSchema) && (0 == strcmp (pSchema, DEFAULT_DOMINO_ONE_TOUCH_SCHMEA_TAG)))
    {
        pBinDir = (getenv (DOMINO_EXEC_DIR_ENV));

        if (pBinDir)
        {
            snprintf (szSchemaFile, sizeof (szSchemaFile), "%s/%s", pBinDir, DOMINO_ONE_TOUCH_SCHMEA_NAME);
        }
        else
            snprintf (szSchemaFile, sizeof (szSchemaFile), "%s/%s", DOMINO_EXEC_DIR_PATH, DOMINO_ONE_TOUCH_SCHMEA_NAME);

       if (0 == stat (szSchemaFile, &fStat))
       {
           if (S_ISREG (fStat.st_mode))
               pSchema = szSchemaFile;
       }
    }

    if (pSchema)
      printf ("schema: [%s]\n", pSchema);

    /* Read and check JSON file first */
    if ( (!pszFile) || (!*pszFile) )
    {
        printf ("\nNo JSON file specified!\n\n");
        ret = 3;
        goto Done;
    }

    fp = fopen(pszFile, "r");
 
    if (NULL == fp)
    {
        printf ("\nCannot open JSON file [%s]\n\n", pszFile);
        ret = 3;
        goto Done;
    }

    FileReadStream jDocStream (fp, szBuffer, sizeof (szBuffer));

    jDoc.ParseStream (jDocStream);

    if (jDoc.HasParseError())
    {
        pStr = GetParseError_En(jDoc.GetParseError());
        if (pStr)
          printf ("\nJSON file parsing error, offset: %lu: %s\n\n", jDoc.GetErrorOffset(), pStr);

        goto Done;
    }

    fclose (fp);
    fp = NULL;

    /* Read and check JSON schema file when specified */
    if ( (!pszSchema) || (!*pszSchema) )
    {
        ret = 0; /* Return JSON is valid without specified schema */
        goto Done;
    }

    fp = fopen (pSchema, "r");

    if (NULL == fp)
    {
        printf ("\nCannot open JSON schema file [%s]\n\n", pSchema);
        ret = 2;
        goto Done;
    }

    FileReadStream jSchemaStream (fp, szBuffer, sizeof (szBuffer));
    jSchemaDoc.ParseStream (jSchemaStream);

    if (jSchemaDoc.HasParseError())
    {
        pStr = GetParseError_En (jSchemaDoc.GetParseError());
        if (pStr)
          printf ("\nJSON schema file parsing error, offset: %lu: %s\n\n", jSchemaDoc.GetErrorOffset(), pStr);

        ret = 1;
        goto Done;
    }

    fclose (fp);
    fp = NULL;

    /* Now that both JSON files are valid, check the schema */
    SchemaDocument jSchema (jSchemaDoc);
    SchemaValidator jValidator (jSchema);

    if (!jDoc.Accept (jValidator))
    {
        rapidjson::StringBuffer jStrBuf;
        jValidator.GetInvalidSchemaPointer().StringifyUriFragment (jStrBuf);

        printf ("\n\nInvalid schema: %s\n", jStrBuf.GetString());
        printf ("Invalid keyword: %s\n", jValidator.GetInvalidSchemaKeyword());

        jStrBuf.Clear();

        jValidator.GetInvalidDocumentPointer().StringifyUriFragment (jStrBuf);
        printf ("Invalid document: %s\n\n", jStrBuf.GetString());
        
        ret = 2;
        goto Done;
    }

    if (jValidator.IsValid())
    {
        printf ("\nJSON file [%s] validated according to schema [%s]!\n\n", pszFile, pSchema);
        ret = 0; /* Return JSON is valid against schema */
    }

Done:
    if (fp)
        fclose (fp);

    return ret;
}

int main(int argc, char *argv[])
{
    int ret = 9;
    char *pszFile   = NULL;
    char *pszSchema = NULL;

    if (argc < 2)
        goto InvalidSyntax;

    pszFile = argv[1];

    if (argc > 2)
        pszSchema = argv[2];

    ret = validate_json (pszFile, pszSchema);

Done:

    return ret;

InvalidSyntax:

    printf ("\nSyntax: %s file.json [schema.json]\n\n", argv[0]);
    return ret;
}

