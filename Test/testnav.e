/* Test AGSMenu. */


OPT OSVERSION=37
OPT PREPROCESS

MODULE '*agsnav'


PROC main() HANDLE
    DEF am = NIL:PTR TO agsnav
    DEF i
    DEF item:PTR TO agsnav_item
    
    NEW am.init()
    am.read_dir()
    
    FOR i := 0 TO am.num_items - 1
        item := am.items[i]
        PrintF('\s\n', item.name)
    ENDFOR
    
EXCEPT DO
    END am
ENDPROC
