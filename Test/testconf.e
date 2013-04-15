/* Test AGSConf. */


OPT OSVERSION=37
OPT PREPROCESS

MODULE '*agsconf'


PROC main() HANDLE
    DEF conf = NIL:PTR TO agsconf
    
    NEW conf.init()
    conf.read('AGS:AGS2.conf')
    
EXCEPT DO
    END conf
ENDPROC
