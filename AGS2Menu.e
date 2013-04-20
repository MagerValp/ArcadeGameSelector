/* Arcade Game Selection version 2. */


OPT PREPROCESS


MODULE 'dos/dos'
MODULE 'exec/memory'
MODULE 'intuition/intuition'
MODULE 'intuition/screens'
MODULE 'graphics/modeid'
MODULE 'graphics/rastport'
MODULE 'graphics/text'
MODULE 'lowlevel'
MODULE 'libraries/lowlevel'
MODULE '*ilbmloader'
MODULE '*agsil'
MODULE '*agsnav'
MODULE '*agsconf'
MODULE '*agsdefs'
MODULE '*palfade'


ENUM ERR_KICKSTART = 1,
     ERR_JOYSTICK,
     ERR_SCREEN,
     ERR_WINDOW,
     ERR_FONT,
     ERR_BACKGROUND,
     ERR_EMPTY,
     ERR_COPY_SRC,
     ERR_COPY_DST,
     ERR_COPY_WRITE


OBJECT ags
    conf:PTR TO agsconf
    nav:PTR TO agsnav
    loader:PTR TO agsil_master
    rport:PTR TO rastport
    current_item:INT
    height:INT
    width:INT
    offset:INT
ENDOBJECT

PROC init(conf, nav, loader, rport) OF ags
    self.conf := conf
    self.nav := nav
    self.loader := loader
    self.rport := rport
    ->self.height := 0
    self.width := 26
    ->self.offset := 0
ENDPROC

PROC end() OF ags
ENDPROC

CONST COPY_BUF_SIZE = 128

PROC copy_file(src_path:PTR TO CHAR, dst_path:PTR TO CHAR) HANDLE
    DEF len
    DEF src_fh = NIL
    DEF dst_fh = NIL
    DEF buf[COPY_BUF_SIZE]:ARRAY OF CHAR

    IF (src_fh := Open(src_path, MODE_OLDFILE)) = NIL THEN Raise(ERR_COPY_SRC)
    IF (dst_fh := Open(dst_path, MODE_NEWFILE)) = NIL THEN Raise(ERR_COPY_DST)
    WHILE (len := Read(src_fh, buf, COPY_BUF_SIZE)) > 0
        IF Write(dst_fh, buf, len) <> len THEN Raise(ERR_COPY_WRITE)
    ENDWHILE
EXCEPT DO
    IF src_fh THEN Close(src_fh)
    IF dst_fh THEN Close(dst_fh)
    IF exception
        PrintF('Copying \s to \s: ')
    ENDIF
    ReThrow()
ENDPROC


CONST REPEAT_DELAY = 8
CONST RAWKEY_Q      = 16
CONST RAWKEY_ESC    = 69
CONST RAWKEY_UP     = 76
CONST RAWKEY_DOWN   = 77
CONST RAWKEY_RETURN = 68

PROC select() OF ags
    DEF key
    DEF rawkey
    DEF quit = FALSE
    DEF portstate
    ->DEF lastrawkey
    -> Counters to delay repeat and screenshot loading.
    DEF up_ctr = 0
    DEF down_ctr = 0
    DEF screenshot_ctr = 0
    
    DEF item:PTR TO agsnav_item
    DEF index
    DEF path[100]:STRING
    DEF pos
    
    self.reload()
    
    REPEAT
        WaitTOF()
        
        IF (portstate := ReadJoyPort(1)) = JP_TYPE_NOTAVAIL THEN Raise(ERR_JOYSTICK)
        
        key := GetKey()
        rawkey := key AND $ffff
        /*
        IF lastrawkey <> rawkey
            PrintF('rawkey = \d\n', rawkey)
            lastrawkey := rawkey
        ENDIF
        */
        IF ((rawkey = RAWKEY_Q) AND (key AND LLKB_RAMIGA)) OR
           (rawkey = RAWKEY_ESC) OR
           (portstate AND JPF_BUTTON_BLUE)
            quit := TRUE
        ENDIF

        IF (portstate AND JPF_JOY_UP) OR (rawkey = RAWKEY_UP)
            IF (up_ctr = 0) OR (up_ctr > REPEAT_DELAY)
                IF self.current_item > 0
                    self.current_item := self.current_item - 1
                    self.redraw(self.current_item, self.current_item + 1)
                    screenshot_ctr := 0
                ELSEIF self.offset > 0
                    self.offset := self.offset - 1
                    self.redraw()
                    screenshot_ctr := 0
                ENDIF
            ENDIF
            INC up_ctr
        ELSE
            up_ctr := 0
        ENDIF
        
        IF (portstate AND JPF_JOY_DOWN) OR (rawkey = RAWKEY_DOWN)
            IF (down_ctr = 0) OR (down_ctr > REPEAT_DELAY)
                IF self.current_item < (self.height - 1)
                    self.current_item := self.current_item + 1
                    self.redraw(self.current_item - 1, self.current_item)
                    screenshot_ctr := 0
                ELSEIF (self.current_item + self.offset) < (self.nav.num_items - 1)
                    self.offset := self.offset + 1
                    self.redraw()
                    screenshot_ctr := 0
                ENDIF
            ENDIF
            INC down_ctr
        ELSE
            down_ctr := 0
        ENDIF
        
        IF (portstate AND JPF_BUTTON_RED) OR (rawkey = RAWKEY_RETURN)
            index := self.current_item + self.offset
            item := self.nav.items[index]
            IF item.type = AGSNAV_TYPE_DIR
                IF self.nav.depth AND (index = 0) -> Go to parent dir.
                    StrCopy(path, self.nav.path)
                    pos := EstrLen(path) - 1
                    REPEAT
                        DEC pos
                    UNTIL (path[pos] = "/") OR (path[pos] = ":")
                    INC pos
                    path[pos] := 0
                    SetStr(path, pos)
                    self.nav.set_path(path)
                    self.nav.depth := self.nav.depth - 1
                    self.reload()
                    screenshot_ctr := 0
                ELSEIF self.nav.depth < 2
                    StrCopy(path, self.nav.path)
                    StrAdd(path, item.name)
                    StrAdd(path, '.ags/')
                    self.nav.set_path(path)
                    self.nav.depth := self.nav.depth + 1
                    self.reload()
                    screenshot_ctr := 0
                ENDIF
            ELSE
                StrCopy(path, self.nav.path)
                StrAdd(path, item.name)
                StrAdd(path, '.run')
                copy_file(path, AGS_RUN_PATH)
                screenshot_ctr := (REPEAT_DELAY + 2) -> Avoid loading now.
                quit := TRUE
            ENDIF
            REPEAT
                portstate := ReadJoyPort(1)
                rawkey := GetKey() AND $ffff
            UNTIL ((portstate AND JPF_BUTTON_RED) = 0) AND (rawkey <> RAWKEY_RETURN)
        ENDIF
        
        IF screenshot_ctr++ = (REPEAT_DELAY + 1)
            self.load_screenshot()
            self.load_text()
        ENDIF
        
    UNTIL quit
    
ENDPROC

PROC reload() OF ags
    IF self.nav.read_dir() = 0 THEN Raise(ERR_EMPTY)
    self.current_item := 0
    self.height := Min(self.nav.num_items, self.conf.menu_height)
    self.offset := 0
    self.redraw()
ENDPROC

PROC redraw(start=0, end=-1) OF ags
    DEF line
    DEF item:PTR TO agsnav_item
    DEF y
    DEF empty->:PTR TO CHAR
    DEF len
    
    empty := '                          ' -> Used for padding.
    IF end = -1
        IF self.nav.num_items < self.conf.menu_height
            SetAPen(self.rport, self.conf.bgcolor)
            RectFill(self.rport,
                     self.conf.menu_x,
                     self.conf.menu_y + (self.conf.font_size * self.nav.num_items),
                     self.conf.menu_x + (self.width * 8) - 1, -> FIXME: calculate
                     self.conf.menu_y + (self.conf.font_size * self.conf.menu_height) - 1)
        ENDIF
        end := self.conf.menu_height - 1
    ENDIF
    SetAPen(self.rport, self.conf.textcolor)
    SetBPen(self.rport, self.conf.bgcolor)
    FOR line := start TO end
        IF line < self.nav.num_items
            IF self.current_item = line
                SetDrMd(self.rport, RP_INVERSVID OR RP_JAM2)
            ELSE
                SetDrMd(self.rport, RP_JAM2)
            ENDIF
            y := self.conf.menu_y +
                 self.rport.font.baseline +
                 (self.conf.font_size * line)
            Move(self.rport, self.conf.menu_x, y)
            item := self.nav.items[self.offset + line]
            Text(self.rport, item.name, item.length)
            len := EstrLen(item.name)
            IF len < self.width
                Text(self.rport, empty + len, self.width - len)
            ENDIF
        ENDIF
    ENDFOR
ENDPROC

PROC get_item_path(path:LONG, suffix:PTR TO CHAR) OF ags
    DEF item:PTR TO agsnav_item
    
    item := self.nav.items[self.current_item + self.offset]
    StrCopy(path, self.nav.path)
    StrAdd(path, item.name)
    StrAdd(path, suffix)
ENDPROC

PROC load_screenshot() OF ags
    DEF path[100]:STRING
    
    self.get_item_path(path, '.iff')
    IF FileLength(path) = -1
        self.loader.send_cmd(AGSIL_LOAD, self.conf.empty_screenshot)
    ELSE
        self.loader.send_cmd(AGSIL_LOAD, path)
    ENDIF
ENDPROC

PROC load_text() OF ags HANDLE
    DEF path[100]:STRING
    DEF len
    DEF line = NIL
    DEF bufsize = 0
    DEF adjust_read
    DEF fh = NIL
    DEF linenum = 0
    DEF y
    
    IF self.conf.text_height = 0 THEN Raise(0)
    
    SetAPen(self.rport, self.conf.bgcolor)
    RectFill(self.rport,
             self.conf.text_x,
             self.conf.text_y,
             self.conf.text_x + (self.conf.text_width * 8) - 1, -> FIXME: calculate
             self.conf.text_y + (self.conf.font_size * self.conf.text_height) - 1)
    
    self.get_item_path(path, '.txt')
    IF FileLength(path) = -1 THEN Raise(0)
    
    bufsize := self.conf.text_width + 2
    line := String(bufsize)
    -> Work around Fgets() bug in V36/V37.
    IF KickVersion(39) THEN adjust_read := 0 ELSE adjust_read := 1
    
    SetAPen(self.rport, self.conf.textcolor)
    SetBPen(self.rport, self.conf.bgcolor)
    SetDrMd(self.rport, RP_JAM2)
    IF (fh := Open(path, OLDFILE)) = NIL THEN Raise(0)
    WHILE (linenum < self.conf.text_height) AND Fgets(fh, line, bufsize - adjust_read)
        len := StrLen(line)
        -> Trim trailing newline.
        IF len > 0
            IF (line[len - 1] = "\n")
                DEC len
                line[len] := 0
            ENDIF
        ENDIF
        -> Fix estring length.
        SetStr(line, len)
        
        IF len > 0
            y := self.conf.text_y +
                 self.rport.font.baseline +
                 (self.conf.font_size * linenum)
            Move(self.rport, self.conf.text_x, y)
            Text(self.rport, line, len)
        ENDIF
        
        INC linenum
    ENDWHILE
    
EXCEPT DO
    IF bufsize THEN END line[bufsize]
ENDPROC


PROC main() HANDLE
    DEF conf = NIL:PTR TO agsconf
    DEF il = NIL:PTR TO ilbmloader
    DEF s = NIL:PTR TO screen
    DEF w = NIL:PTR TO window
    DEF pointer = NIL:PTR TO INT
    DEF s_width = 640
    DEF s_height = 256
    DEF s_depth = 4
    DEF s_mode
    DEF ta:textattr
    DEF font = NIL:PTR TO textfont
    DEF loader = NIL:PTR TO agsil_master    -> Background image loader master object.
    DEF reply
    DEF xy
    DEF nav = NIL:PTR TO agsnav             -> Menu directory navigator.
    DEF ags = NIL:PTR TO ags                -> Application controller.
    
    IF KickVersion(37) = FALSE THEN Raise(ERR_KICKSTART)
    
    IF (lowlevelbase := OpenLibrary('lowlevel.library', 0)) = NIL THEN Raise("LOWL")
    
    NEW conf.init()
    conf.read('AGS:AGS2.conf')
    
    IF SetJoyPortAttrsA(1, [SJA_TYPE, SJA_TYPE_JOYSTK, 0]) = FALSE
        Raise(ERR_JOYSTICK)
    ENDIF
    
    NEW loader.init()
    loader.start()
    
    NEW il.init()
    IF il.open(conf.background) = FALSE THEN Raise(ERR_BACKGROUND)
    IF il.parse_header() = FALSE THEN Raise(ERR_BACKGROUND)
    IF conf.mode = AGSCONF_AUTODETECT
        s_mode := IF il.mode THEN il.mode ELSE (PAL_MONITOR_ID OR HIRES_KEY)
    ELSE
        s_mode := conf.mode
    ENDIF
    s_width := il.width
    s_height := il.height
    IF conf.depth = AGSCONF_AUTODETECT
        s_depth := il.depth
    ELSE
        s_depth := conf.depth
    ENDIF
    
    IF (s := OpenScreenTagList(NIL, [
            SA_WIDTH, s_width,
            SA_HEIGHT, s_height,
            SA_DEPTH, s_depth,
            SA_DISPLAYID, s_mode,
            SA_DRAGGABLE, FALSE,
            SA_SHOWTITLE, FALSE,
            SA_BEHIND, TRUE,
            0])) = NIL THEN Raise(ERR_SCREEN)
    IF (w := OpenWindowTagList(NIL, [
            WA_CUSTOMSCREEN, s,
            WA_WIDTH, s_width,
            WA_HEIGHT, s_height,
            WA_TITLE, 0,
            WA_CLOSEGADGET, FALSE,
            WA_BORDERLESS, TRUE,
            WA_RMBTRAP, TRUE,
            WA_ACTIVATE, TRUE,
            0])) = NIL THEN Raise(ERR_WINDOW)
    
    pointer := NewM(4, MEMF_CHIP OR MEMF_CLEAR)
    SetPointer(w, pointer, 1, 1, 0, 0)
    
    ta.name := conf.font
    ta.ysize := conf.font_size
    ta.style := 0
    ta.flags := 0
    IF (font := OpenFont(ta)) = NIL THEN Raise(ERR_FONT)
    SetFont(w.rport, font)
    
    fade_out_vport(s.viewport, Shl(1, s_depth), 1) -> Clear palette to black.
    il.load_body(w.rport, 0, 0)
    ScreenToFront(s)
    fade_in_vport(il.colormap, s.viewport, Shl(1, s_depth), 10)
    il.close()
    END il
    
    loader.wait_port()
    reply := loader.send_cmd(AGSIL_SETRPORT, w.rport)
    reply := loader.send_cmd(AGSIL_SETVPORT, s.viewport)
    reply := loader.send_cmd(AGSIL_SETMAXCOLORS, Shl(1, s_depth) - conf.lock_colors)
    /* We loaded the background image directly using ilbmloader instead.
    reply := loader.send_cmd(AGSIL_SETXY, 0)
    reply := loader.send_cmd(AGSIL_LOAD, bkg_img)
    IF reply < 0 THEN Raise(ERR_BACKGROUND)
    loader.wait_load(reply)
    */
    xy := Shl(conf.screenshot_x, 16) OR conf.screenshot_y
    reply := loader.send_cmd(AGSIL_SETXY, xy)
    
    NEW nav.init()
    
    NEW ags.init(conf, nav, loader, w.rport)
    ags.select()
    fade_out_vport(s.viewport, Shl(1, s_depth), 10)
    
    loader.stop()

EXCEPT DO
    END ags
    END nav
    END loader
    END il
    IF font THEN CloseFont(font)
    IF pointer THEN Dispose(pointer)
    IF w THEN CloseWindow(w)
    IF s THEN CloseScreen(s)
    SetJoyPortAttrsA(1, [SJA_REINITIALIZE, 0, 0])
    END conf
    IF lowlevelbase THEN CloseLibrary(lowlevelbase)
    SELECT exception
        CASE "MEM"
            PrintF('Out of memory.\n')
        CASE AGSIL_ERROR
            PrintF('\s.\n', agsil_strerror(exceptioninfo))
        CASE AGSNAV_ERROR
            PrintF('\s.\n', agsnav_strerror(exceptioninfo))
        CASE AGSCONF_ERROR
            PrintF('\s.\n', agsconf_strerror(exceptioninfo))
        CASE ILBM_ERROR
            PrintF('\s\n', ilbm_strerror(exceptioninfo))
        CASE ERR_KICKSTART
            PrintF('Requires Kickstart 2.0+.\n')
        CASE ERR_JOYSTICK
            PrintF('Couldn''t read joystick.\n')
        CASE ERR_SCREEN
            PrintF('Couldn''t open screen.\n')
        CASE ERR_WINDOW
            PrintF('Couldn''t open window.\n')
        CASE ERR_FONT
            PrintF('Couldn''t open font.\n')
        CASE ERR_BACKGROUND
            PrintF('Couldn''t load background image.\n')
        CASE ERR_EMPTY
            PrintF('Menu is empty, nothing to select.\n')
        CASE ERR_COPY_SRC
            PrintF('Error opening source.\n')
        CASE ERR_COPY_DST
            PrintF('Error opening destination.\n')
        CASE ERR_COPY_WRITE
            PrintF('Error writing run script.\n')
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
