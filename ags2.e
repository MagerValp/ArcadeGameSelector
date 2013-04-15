/* Arcade Game Selection version 2. */


OPT PREPROCESS


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


ENUM ERR_KICKSTART = 1,
     ERR_JOYSTICK,
     ERR_SCREEN,
     ERR_WINDOW,
     ERR_FONT,
     ERR_BACKGROUND,
     ERR_EMPTY


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
            ENDIF
            REPEAT
                portstate := ReadJoyPort(1)
                rawkey := GetKey() AND $ffff
            UNTIL ((portstate AND JPF_BUTTON_RED) = 0) AND (rawkey <> RAWKEY_RETURN)
        ENDIF
        
        IF screenshot_ctr++ = (REPEAT_DELAY + 1)
            self.load_screenshot()
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
            SetAPen(self.rport, 254)
            RectFill(self.rport,
                     self.conf.menu_x,
                     self.conf.menu_y + (self.conf.font_size * self.nav.num_items),
                     self.conf.menu_x + (self.width * 8) - 1, -> FIXME: calculate
                     self.conf.menu_y + (self.conf.font_size * self.conf.menu_height) - 1)
        ENDIF
        end := self.conf.menu_height - 1
    ENDIF
    SetAPen(self.rport, 255)
    SetBPen(self.rport, 254)
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

PROC load_screenshot() OF ags
    DEF path[100]:STRING
    DEF item:PTR TO agsnav_item
    
    item := self.nav.items[self.current_item + self.offset]
    StrCopy(path, self.nav.path)
    StrAdd(path, item.name)
    StrAdd(path, '.iff')
    IF FileLength(path) = -1
        self.loader.send_cmd(AGSIL_LOAD, self.conf.empty_screenshot)
    ELSE
        self.loader.send_cmd(AGSIL_LOAD, path)
    ENDIF
ENDPROC


PROC main() HANDLE
    DEF conf = NIL:PTR TO agsconf
    DEF il = NIL:PTR TO ilbmloader
    DEF s = NIL:PTR TO screen
    DEF w = NIL:PTR TO window
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
    
    ta.name := conf.font
    ta.ysize := conf.font_size
    ta.style := 0
    ta.flags := 0
    IF (font := OpenFont(ta)) = NIL THEN Raise(ERR_FONT)
    SetFont(w.rport, font)
    
    il.load_cmap(s.viewport)
    il.load_body(w.rport, 0, 0)
    il.close()
    END il
    
    loader.wait_port()
    reply := loader.send_cmd(AGSIL_SETRPORT, w.rport)
    reply := loader.send_cmd(AGSIL_SETVPORT, s.viewport)
    /* We loaded the background image directly using ilbmloader instead.
    reply := loader.send_cmd(AGSIL_SETXY, 0)
    reply := loader.send_cmd(AGSIL_LOAD, bkg_img)
    IF reply < 0 THEN Raise(ERR_BACKGROUND)
    loader.wait_load(reply)
    */
    xy := Shl(conf.screenshot_x, 16) OR conf.screenshot_y
    reply := loader.send_cmd(AGSIL_SETXY, xy)
    ScreenToFront(s)
    
    NEW nav.init()
    
    NEW ags.init(conf, nav, loader, w.rport)
    ags.select()
    
    loader.stop()

EXCEPT DO
    END ags
    END nav
    END loader
    END il
    IF font THEN CloseFont(font)
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
        DEFAULT
            IF exception
                PrintF('Unknown exception "\s" / $\h[08]\n',
                       [exception, 0],
                       exception)
            ENDIF
    ENDSELECT
ENDPROC
