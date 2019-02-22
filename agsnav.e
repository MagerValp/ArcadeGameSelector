/* AGSNav navigates and parses the menu directory structure. */

OPT MODULE


MODULE 'dos/dos'
MODULE 'dos/dosextens'
MODULE 'dos/exall'


EXPORT CONST AGSNAV_ERROR = "AGSM"
EXPORT ENUM AGSNAV_ERR_LOCK = 1, AGSNAV_ERR_EXALL

EXPORT PROC agsnav_strerror(num:LONG) IS ListItem([
        'Couldn''t lock directory',
        'Error reading directory'
    ], num - 1)


EXPORT ENUM AGSNAV_TYPE_DIR = 1, AGSNAV_TYPE_FILE = 2

EXPORT OBJECT agsnav_item
    name -> STRING
    length:LONG
    type:LONG
ENDOBJECT


EXPORT OBJECT agsnav
    path -> STRING
    depth:LONG
    num_items:LONG
    items:PTR TO LONG -> PTR TO ARRAY OF agsnav_item
    reserved:LONG
ENDOBJECT


PROC init() OF agsnav
    self.set_path('AGS:')
ENDPROC

PROC set_path(path:PTR TO CHAR) OF agsnav
    IF self.path THEN DisposeLink(self.path)
    self.path := String(StrLen(path) + 1)
    StrCopy(self.path, path)
ENDPROC

PROC end() OF agsnav
    self.clear(0)
    IF self.path THEN DisposeLink(self.path)
ENDPROC

-> Clear the current navigator and allocate enough space for num_reserve items.
PROC clear(num_reserve:LONG) OF agsnav
    DEF i
    DEF item:PTR TO agsnav_item
    ->DEF name:PTR TO CHAR
    
    IF self.items
        FOR i := 0 TO self.num_items - 1
            item := self.items[i]
            DisposeLink(item.name)
            END item
        ENDFOR
        END self.items[self.reserved]
    ENDIF
    self.num_items := 0
    
    IF num_reserve
        IF self.depth THEN INC num_reserve
        NEW self.items[num_reserve]
        self.reserved := num_reserve
        IF self.depth THEN self.add_item('..', AGSNAV_TYPE_DIR)
    ENDIF
ENDPROC

PROC compare_items(item1:PTR TO agsnav_item, item2:PTR TO agsnav_item)
    IF item2.type > item1.type THEN RETURN 1
    IF item2.type < item1.type THEN RETURN -1
ENDPROC OstrCmp(item1.name, item2.name)

-> Insert the item into a sorted list, with directories before files.
PROC add_item(name:PTR TO CHAR, type:LONG) OF agsnav
    DEF item:PTR TO agsnav_item
    DEF pos, found
    DEF i
    
    NEW item
    item.type := type
    item.name := String(StrLen(name) + 1)
    StrCopy(item.name, name)
    item.length := EstrLen(item.name)
    IF self.num_items = 0
        self.items[0] := item
    ELSE
        pos := 0
        found := FALSE
        WHILE found = FALSE
            IF pos >= self.num_items
                found := TRUE
            ELSEIF compare_items(self.items[pos], item) <= 0
                found := TRUE
            ELSE
                INC pos
            ENDIF
        ENDWHILE
        IF pos < self.num_items
            FOR i := self.num_items TO pos STEP -1
                self.items[i] := self.items[i - 1]
            ENDFOR
        ENDIF
        self.items[pos] := item
    ENDIF
    self.num_items := self.num_items + 1
ENDPROC

PROC str_ends_with(str, suffix)
    DEF str_len
    DEF suffix_len
    
    str_len := StrLen(str)
    suffix_len := StrLen(suffix)
    IF str_len < suffix_len THEN RETURN FALSE
ENDPROC InStr(str, suffix, str_len - suffix_len) <> -1


-> Clear the current menu, read the current directory, and add all menu items.
CONST BUFSIZE = 512
PROC read_dir() OF agsnav HANDLE
    DEF lock = NIL:PTR TO filelock
    DEF eac = NIL:PTR TO exallcontrol
    DEF ead:PTR TO exalldata
    DEF buffer[BUFSIZE]:ARRAY OF CHAR
    DEF continue
    DEF error
    
    DEF first = NIL -> :PTR TO STRING
    DEF current = NIL -> :PTR TO STRING
    DEF num_items = 0
    DEF next = NIL -> :PTR TO STRING
    DEF should_add
    
    DEF name[30]:STRING
    DEF type
    
    -> Read the current directory with ExAll().
    IF (lock := Lock(self.path, ACCESS_READ)) = FALSE
        Throw(AGSNAV_ERROR, AGSNAV_ERR_LOCK)
    ENDIF
    eac := AllocDosObject(DOS_EXALLCONTROL, NIL)
    eac.lastkey := 0
    eac.matchstring := NIL
    eac.matchfunc := NIL
    REPEAT
        continue := ExAll(lock, buffer, BUFSIZE, ED_TYPE, eac)
        error := IoErr()
        IF (continue = 0) AND (error <> ERROR_NO_MORE_ENTRIES)
            Throw(AGSNAV_ERROR, AGSNAV_ERR_EXALL)
        ENDIF
        IF eac.entries
            ead := buffer
            WHILE ead <> NIL
                -> Only add directories and files ending with .run.
                IF (ead.type > 0) AND str_ends_with(ead.name, '.ags')
                    should_add := TRUE
                ELSEIF str_ends_with(ead.name, '.run')
                    should_add := TRUE
                ELSE
                    should_add := FALSE
                ENDIF
                IF should_add
                    -> For each entry allocate a string for the name and set the
                    -> first character to D for directories and F for files.
                    next := String(StrLen(ead.name) + 1)
                    IF ead.type < 0
                        StrCopy(next, 'F')
                    ELSE
                        StrCopy(next, 'D')
                    ENDIF
                    StrAdd(next, ead.name)
                    IF current = NIL
                        current := next
                        first := next
                    ELSE
                        Link(current, next)
                        current := next
                    ENDIF
                    INC num_items
                ENDIF
                ead := ead.next
            ENDWHILE
        ENDIF
    UNTIL continue = FALSE
    
    self.clear(num_items)
    
    current := first
    WHILE current
        IF current[0] = "F"
            type := AGSNAV_TYPE_FILE
            StrCopy(name, current + 1, EstrLen(current) - 5)
        ELSE
            type := AGSNAV_TYPE_DIR
            StrCopy(name, current + 1, EstrLen(current) - 5)
        ENDIF
        self.add_item(name, type)
        next := Next(current)
        current := next
    ENDWHILE
    DisposeLink(current)
    
EXCEPT DO
    IF eac THEN FreeDosObject(DOS_EXALLCONTROL, eac)
    IF lock THEN UnLock(lock)
    ReThrow()
ENDPROC self.num_items
