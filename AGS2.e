/* AGS Launcher. */


OPT PREPROCESS


->MODULE 'dos/dos'
MODULE '*agsdefs'


ENUM ERR_MENU = 1,
     ERR_RUN,
     ERR_DELETE

#define AGS_MENU_PATH 'AGS:AGS2Menu'
#define AGS_EXECUTE_COMMAND 'Execute ' + AGS_RUN_PATH


PROC main() HANDLE
    
    LOOP
        -> Start AGS2Menu.
        IF SystemTagList(AGS_MENU_PATH, [NIL]) = -1 THEN Raise(ERR_MENU)
        -> Check if there's a RAM:AGS.run for us, otherwise exit.
        IF FileLength(AGS_RUN_PATH) = -1 THEN Raise(0)
        -> Execute RAM:AGS.run.
        IF SystemTagList(AGS_EXECUTE_COMMAND, [NIL]) = -1 THEN Raise(ERR_RUN)
        -> Delete RAM:AGS.run.
        IF DeleteFile(AGS_RUN_PATH) = FALSE THEN Raise(ERR_DELETE)
    ENDLOOP
    
EXCEPT DO
    SELECT exception
        CASE ERR_MENU
            PrintF('Couldn''t execute ' + AGS_MENU_PATH + '\n')
        CASE ERR_RUN
            PrintF('Couldn''t execute ' + AGS_RUN_PATH + '\n')
        CASE ERR_DELETE
            PrintF('Couldn''t delete ' + AGS_RUN_PATH + '\n')
        DEFAULT
            IF exception
                IF exception < 10000
                    PrintF('Unknown exception \d\n', exception)
                ELSE
                    PrintF('Unknown exception "\s"', [exception, 0])
                ENDIF
            ENDIF
    ENDSELECT
ENDPROC
