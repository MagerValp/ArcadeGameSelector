/* Test AGSImgLoader by sending messages. */


OPT OSVERSION=37
OPT PREPROCESS

OBJECT testobj
    cbool:CHAR
    ibool:INT
ENDOBJECT

PROC main() HANDLE
    ->DEF to:PTR TO testobj
    PrintFault(205, 'hejsan')
EXCEPT DO
ENDPROC
