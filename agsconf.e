/* AGSConf reads and stores application configuration. */

OPT MODULE


MODULE 'dos/dos'
->MODULE 'dos/dosextens'
->MODULE 'dos/exall'


EXPORT CONST AGSCONF_ERROR = "AGSC"
EXPORT ENUM AGSCONF_ERR_READ = 1, AGSCONF_ERR_VALUE, AGSCONF_ERR_UNKNOWN
EXPORT ENUM AGSCONF_ACTION_NONE = 0, AGSCONF_ACTION_QUIT = 1


EXPORT PROC agsconf_strerror(num:LONG) IS ListItem([
        'Error reading config file',
        'Illegal value',
        'Unknown option'
    ], num - 1)


EXPORT CONST AGSCONF_AUTODETECT = -1

EXPORT OBJECT agsconf
    background:LONG -> PTR TO STRING -> AGS:AGS2Background.iff
    mode:LONG -> = $29000
    depth:INT -> = 4
    lock_colors:INT -> = 4

    font_name:LONG -> PTR TO STRING -> topaz.font
    font_size:INT -> = 8
    font_leading:INT -> = 0

    menu_x:INT -> = 24
    menu_y:INT -> = 8
    menu_height:INT -> = 30

    screenshot_x:INT -> = 304
    screenshot_y:INT -> = 8
    empty_screenshot:LONG -> PTR TO STRING -> AGS:Empty.iff

    text_x:INT
    text_y:INT
    text_width:INT
    text_height:INT
    text_color:INT -> = 255
    text_background:INT -> = 254

    blue_button_action:LONG -> AGSCONF_ACTION_QUIT

    slideshow_delay_secs:INT -> = 0 (disabled)
    slideshow_start_index:INT -> = 1
    slideshow_end_index:INT -> = 7
ENDOBJECT

-> Initialize with default configuration.
PROC init() OF agsconf
    self.background := String(128)
    self.font_name := String(32)
    self.empty_screenshot := String(128)

    StrCopy(self.background, 'AGS:AGS2Background.iff')
    self.mode := AGSCONF_AUTODETECT
    self.depth := AGSCONF_AUTODETECT
    self.text_color := 255
    self.text_background := 254
    self.lock_colors := 4

    StrCopy(self.font_name, 'topaz.font')
    self.font_size := 8
    self.font_leading := 0

    self.menu_x := 24
    self.menu_y := 8
    self.menu_height := 30

    self.screenshot_x := 304
    self.screenshot_y := 8
    StrCopy(self.empty_screenshot, 'AGS:Empty.iff')

    self.text_x := 304
    self.text_y := 144
    self.text_width := 40
    self.text_height := (248 - self.text_y) / self.font_size

    self.blue_button_action := AGSCONF_ACTION_QUIT

    self.slideshow_delay_secs := 0
    self.slideshow_start_index := 1
    self.slideshow_end_index := 7
ENDPROC

PROC end() OF agsconf
    DisposeLink(self.background)
    DisposeLink(self.font_name)
    DisposeLink(self.empty_screenshot)
ENDPROC

PROC set_value(key:PTR TO CHAR, value:PTR TO CHAR) OF agsconf
    DEF num, read

    IF StrCmp(key, 'background')
        StrCopy(self.background, value)
    ELSEIF StrCmp(key, 'font')
        StrCopy(self.font_name, value)
    ELSEIF StrCmp(key, 'empty_screenshot')
        StrCopy(self.empty_screenshot, value)
    ELSEIF StrCmp(key, 'blue_button_action')
        IF StrCmp(value, 'quit')
            self.blue_button_action := AGSCONF_ACTION_QUIT
        ELSEIF StrCmp(value, 'none')
            self.blue_button_action := AGSCONF_ACTION_NONE
        ELSE
            Throw(AGSCONF_ERROR, AGSCONF_ERR_UNKNOWN)
        ENDIF
    ELSE
        num, read := Val(value)
        IF read = 0 THEN Throw(AGSCONF_ERROR, AGSCONF_ERR_VALUE)
        IF StrCmp(key, 'mode')
            self.mode := num
        ELSEIF StrCmp(key, 'depth')
            self.depth := num
        ELSEIF StrCmp(key, 'text_color')
            self.text_color := num
        ELSEIF StrCmp(key, 'text_background')
            self.text_background := num
        ELSEIF StrCmp(key, 'lock_colors')
            self.lock_colors := num
        ELSEIF StrCmp(key, 'font_size')
            self.font_size := num
        ELSEIF StrCmp(key, 'font_leading')
            self.font_leading := num
        ELSEIF StrCmp(key, 'menu_x')
            self.menu_x := num
        ELSEIF StrCmp(key, 'menu_y')
            self.menu_y := num
        ELSEIF StrCmp(key, 'menu_height')
            self.menu_height := num
        ELSEIF StrCmp(key, 'screenshot_x')
            self.screenshot_x := num
        ELSEIF StrCmp(key, 'screenshot_y')
            self.screenshot_y := num
        ELSEIF StrCmp(key, 'text_x')
            self.text_x := num
        ELSEIF StrCmp(key, 'text_y')
            self.text_y := num
        ELSEIF StrCmp(key, 'text_width')
            self.text_width := num
        ELSEIF StrCmp(key, 'text_height')
            self.text_height := num
        ELSEIF StrCmp(key, 'slideshow_delay_secs')
            self.slideshow_delay_secs := num
        ELSEIF StrCmp(key, 'slideshow_start_index')
            self.slideshow_start_index := num
        ELSEIF StrCmp(key, 'slideshow_end_index')
            self.slideshow_end_index := num
        ELSE
            Throw(AGSCONF_ERROR, AGSCONF_ERR_UNKNOWN)
        ENDIF
    ENDIF
ENDPROC

CONST BUFSIZE=128

PROC read(filename:PTR TO CHAR) OF agsconf HANDLE
    DEF fh = NIL
    DEF line[BUFSIZE]:STRING
    DEF bufsize
    DEF linenum = 0
    DEF len
    DEF pos
    DEF key[32]:STRING
    DEF value[96]:STRING

    IF (fh := Open(filename, OLDFILE)) = NIL
        IF IoErr() = 205
            Raise(0)
        ELSE
            PrintFault(IoErr(), filename)
            Throw(AGSCONF_ERROR, AGSCONF_ERR_READ)
        ENDIF
    ENDIF

    IF KickVersion(39)
        bufsize := BUFSIZE
    ELSE
        -> Workaround for bug in V36/V37.
        bufsize := BUFSIZE - 1
    ENDIF
    -> Read a line at a time, max BUFSIZE - 1 characters per line.
    WHILE Fgets(fh, line, bufsize)
        INC linenum

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
        ->PrintF('Config line \d: "\s"\n', linenum, line)

        IF len = 0
            -> Skip empty lines.
        ELSEIF line[0] = "#"
            -> Skip comment lines.
        ELSE
            -> Split string on first occurence of =.
            pos := InStr(line, '=')
            IF pos < 1
                Throw(AGSCONF_ERROR, AGSCONF_ERR_READ)
            ENDIF
            -> Copy left hand side as the config key name.
            MidStr(key, line, 0, pos)
            -> Trim trailing spaces.
            len := EstrLen(key)
            WHILE (len > 0) AND (key[len - 1] = " ") DO DEC len
            SetStr(key, len)

            -> Copy right hand side as the config value, skipping leading
            -> spaces.
            INC pos
            WHILE (pos < EstrLen(line)) AND (line[pos] = " ") DO INC pos
            IF pos = EstrLen(line)
                Throw(AGSCONF_ERROR, AGSCONF_ERR_READ)
            ENDIF
            MidStr(value, line, pos, EstrLen(line) - pos)
            -> Trim trailing spaces.
            len := EstrLen(value)
            WHILE (len > 0) AND (value[len - 1] = " ") DO DEC len
            SetStr(value, len)

            self.set_value(key, value)
        ENDIF

    ENDWHILE

EXCEPT DO
    IF fh THEN Close(fh)
    IF exception
        IF linenum THEN PrintF('\s error on line \d\n', filename, linenum)
        ReThrow()
    ENDIF
ENDPROC
