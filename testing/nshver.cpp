


#include <global.h>
#include <addin.h>
#include <misc.h>
#include <stdio.h>

int main (int argc, char *argv[])
{
    STATUS error = NOERROR;
    char szBuild[MAXSPRINTF+1] = {0};

    error = NotesInitExtended (argc, argv);

    if (error)
    {
        printf ("C-API init error: %u", error);
        return error;
    }

    AddInFormatError (szBuild, 1);
    printf ("DominoVersion=%s\n", szBuild);

    NotesTerm();
    return 0;
}

