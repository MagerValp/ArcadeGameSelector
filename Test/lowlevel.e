OPT PREPROCESS,REG=3

MODULE 'intuition/screens', 'intuition/intuition', 'graphics/modeid',
       'dos/dos', 'graphics/rastport', 'graphics/text', 'lowlevel',
       'libraries/lowlevel', 'tools/ilbm', 'tools/ilbmdefs', 'exec/memory',
       'graphics/gfx'


PROC main() HANDLE
    DEF s = NIL:PTR TO screen
    DEF w = NIL:PTR TO window
    DEF portstate
    DEF font:PTR TO textfont
    DEF ta:textattr
    DEF sx = 16
    DEF sy = 8
    DEF key
    DEF rawkey
    
    IF (lowlevelbase := OpenLibrary('lowlevel.library', 0)) = NIL THEN Raise("LOWL")

    IF SetJoyPortAttrsA(1, [SJA_TYPE, SJA_TYPE_JOYSTK, 0]) = FALSE
        Raise("JATR")
    ENDIF
    
    IF (s := OpenScreenTagList(NIL, [
            SA_WIDTH, 640,
            SA_HEIGHT, 256,
            SA_DEPTH, 4,
            SA_DISPLAYID, HIRES_KEY,
->            SA_DISPLAYID,$50041000,
            SA_DRAGGABLE, FALSE,
            SA_SHOWTITLE, FALSE,
            0])) = NIL THEN Raise("SCRN")
    IF (w := OpenWindowTagList(NIL, [
            WA_CUSTOMSCREEN, s,
            WA_WIDTH, 640,
            WA_HEIGHT, 256,
            WA_TITLE, 0,
            WA_CLOSEGADGET, FALSE,
            WA_BORDERLESS, TRUE,
            WA_RMBTRAP, TRUE,
            WA_ACTIVATE, TRUE,
            0])) = NIL THEN Raise("WIND")

    ->SetPointer(w, mouseptr, 1, 1, 0, 0)

    ta.name := 'topaz.font'
    ta.ysize := 8
    ta.style := 0
    ta.flags := 0
    IF (font := OpenFont(ta)) = NIL THEN Raise("FONT")
    SetFont(w.rport, font)

    SetAPen(w.rport, 255)
    SetBPen(w.rport, 254)
    SetDrMd(w.rport, RP_JAM2)
    
    LOOP
        WaitTOF()
        
        key := GetKey()
        rawkey := key AND $ffff
        
        IF (rawkey = 16) AND (key AND LLKB_RAMIGA) -> RAmiga-Q
            Raise("QUIT")
        ELSEIF rawkey = 69 -> Esc
            Raise("QUIT")
        ENDIF
        
        IF ((portstate := ReadJoyPort(1)) = JP_TYPE_NOTAVAIL)
            Raise("JTYP")
        ENDIF

->        IF (portstate AND JPF_BUTTON_RED)
->            Raise("QUIT")
->        ELSEIF (portstate AND JPF_BUTTON_BLUE)
->            Raise("QUIT")
->        ENDIF

        Move(w.rport, 6 * sx, (3 * sy) + w.rport.font.baseline)
        IF (portstate AND JPF_BUTTON_RED)
            Text(w.rport, 'Rd', 2)
        ELSE
            Text(w.rport, '  ', 2)
        ENDIF

        Move(w.rport, 6 * sx, (5 * sy) + w.rport.font.baseline)
        IF (portstate AND JPF_BUTTON_BLUE)
            Text(w.rport, 'Bl', 2)
        ELSE
            Text(w.rport, '  ', 2)
        ENDIF

        Move(w.rport, 3 * sx, (3 * sy) + w.rport.font.baseline)
        IF (portstate AND JPF_JOY_UP)
            Text(w.rport, '/\\', 2)
        ELSE
            Text(w.rport, '  ', 2)
        ENDIF

        Move(w.rport, 3 * sx, (5 * sy) + w.rport.font.baseline)
        IF (portstate AND JPF_JOY_DOWN)
            Text(w.rport, '\\/', 2)
        ELSE
            Text(w.rport, '  ', 2)
        ENDIF

        Move(w.rport, 2 * sx, (4 * sy) + w.rport.font.baseline)
        IF (portstate AND JPF_JOY_LEFT)
            Text(w.rport, '< ', 2)
        ELSE
            Text(w.rport, '  ', 2)
        ENDIF

        Move(w.rport, 4 * sx, (4 * sy) + w.rport.font.baseline)
        IF (portstate AND JPF_JOY_RIGHT)
            Text(w.rport, ' >', 2)
        ELSE
            Text(w.rport, '  ', 2)
        ENDIF

    ENDLOOP


EXCEPT DO
    IF font THEN CloseFont(font)
    IF w THEN CloseWindow(w)
    IF s THEN CloseScreen(s)
    SetJoyPortAttrsA(1, [SJA_REINITIALIZE, 0, 0])
    SELECT exception
        CASE "QUIT"
        CASE "FONT" ; PrintF('Couldn''t OpenFont() topaz 8...?\n')
        CASE "LOCK" ; PrintF('Couldn''t lock AGS:.\n')
        CASE "EXAM" ; PrintF('Couldn''t examine AGS:.\n')
        CASE "NONE" ; PrintF('No start files found.\n')
        CASE "MEM"    ; PrintF('Out of memory.\n')
        CASE "SCRN" ; PrintF('Couldn''t open screen.\n')
        CASE "WIND" ; PrintF('Couldn''t open window.\n')
        CASE "INFL" ; PrintF('Couldn''t open infile.\n')
        CASE "OUTF" ; PrintF('Couldn''t open outfile.\n')
        CASE "WERR" ; PrintF('Write error.\n')
        CASE "LOWL" ; PrintF('Couldn''t open lowlevel.library.\n')
        CASE "JATR" ; PrintF('Couldn''t setup joyport.\n')
        CASE "JTYP" ; PrintF('Couldn''t check joystick.\n')
        DEFAULT
            PrintF('Unknown exception: \z\h[8]\n',exception)
    ENDSELECT
ENDPROC
