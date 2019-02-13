/* De/serialize navigation and menu position */

OPT PREPROCESS
OPT MODULE

MODULE 'dos/dos'

#define AGS_MENUPOS_PATH 'RAM:AGS.pos'

EXPORT OBJECT agsmenupos
    path -> STRING
    depth:LONG
    offset:LONG
    pos:LONG
ENDOBJECT

CONST BUFSIZE=256

PROC init() OF agsmenupos
    self.path := String(BUFSIZE)
ENDPROC

PROC end() OF agsmenupos
    DisposeLink(self.path)
ENDPROC

PROC read() OF agsmenupos HANDLE
    DEF fh = NIL
    DEF line[BUFSIZE]:STRING
    DEF linenum = 0
    DEF bufsize, len, num, read

    IF KickVersion(39) THEN bufsize := BUFSIZE ELSE bufsize := BUFSIZE - 1

    IF fh := Open(AGS_MENUPOS_PATH, MODE_OLDFILE)
        WHILE Fgets(fh, line, bufsize)
            INC linenum
            SELECT linenum
            CASE 1
                len := StrLen(line)
                IF len > 0
                    IF (line[len - 1] = "\n")
                        DEC len
                        line[len] := 0
                    ENDIF
                ENDIF
                SetStr(line, len)
                StrCopy(self.path, line)
            CASE 2
                num, read := Val(line)
                IF read <> 0 THEN self.depth := num
            CASE 3
                num, read := Val(line)
                IF read <> 0 THEN self.offset := num
            CASE 4
                num, read := Val(line)
                IF read <> 0 THEN self.pos := num
            CASE 5
                JUMP break
            ENDSELECT
        ENDWHILE
        break:
        Close(fh)
        DeleteFile(AGS_MENUPOS_PATH)
    ELSE
        StrCopy(self.path, 'AGS:')
    ENDIF
EXCEPT DO
    IF fh THEN Close(fh)
    DeleteFile(AGS_MENUPOS_PATH)
ENDPROC

PROC write(path:PTR TO CHAR, depth, offset, pos) OF agsmenupos HANDLE
    DEF fh = NIL

    StrCopy(self.path, path)
    self.depth := depth
    self.offset := offset
    self.pos := pos

    IF fh := Open(AGS_MENUPOS_PATH, MODE_NEWFILE)
        VfPrintf(fh, '\s\n\d\n\d\n\d', [self.path, self.depth, self.offset, self.pos]:LONG)
        Close(fh)
    ENDIF
EXCEPT DO
    IF fh THEN Close(fh)
    DeleteFile(AGS_MENUPOS_PATH)
ENDPROC
