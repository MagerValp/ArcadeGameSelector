/* Background image loading handler. */


OPT OSVERSION=37
OPT PREPROCESS

MODULE 'amigalib/lists'
MODULE 'other/ecode'
MODULE 'exec/interrupts'
MODULE 'exec/memory'
MODULE 'exec/ports'
MODULE 'exec/nodes'
MODULE 'exec/lists'
MODULE 'graphics/rastport'
MODULE 'graphics/view'
->MODULE '*benchmark'
MODULE '*agsil'
MODULE '*ilbmloader'
MODULE '*palfade'
MODULE '*agsconf'
MODULE 'devices/timer'
MODULE 'exec/io'


ENUM ERR_NONE, ERR_ECODE, ERR_CREATEPORT, ERR_CREATETIMER

ENUM LDR_LOADING, LDR_QUITTING


CONST PATH_LEN=100

OBJECT loader
    port:PTR TO mp
    status:LONG
    rport:PTR TO rastport
    vport:PTR TO viewport
    conf:PTR TO agsconf
    max_colors:INT
    img_num:LONG
    img_path
    img_loaded:LONG
ENDOBJECT

DEF item_changed = 0

-> This will be called every time a software interrupt is triggered.
-> Does not need to be reentrant and the main task is suspended while it
-> executes.
PROC softint_handler(ldr:PTR TO loader)
    DEF msg:PTR TO agsil_msg
    DEF action

    msg := GetMsg(ldr.port)
    msg.reply := 0
    action := msg.action
    SELECT action
        CASE AGSIL_QUIT
            ldr.status := LDR_QUITTING
        CASE AGSIL_SETRPORT
            ldr.rport := msg.arg
        CASE AGSIL_SETVPORT
            ldr.vport := msg.arg
        CASE AGSIL_SETCONF
            ldr.conf := msg.arg
        CASE AGSIL_SETMAXCOLORS
            ldr.max_colors := msg.arg
        CASE AGSIL_LOAD
            IF (ldr.rport = NIL) OR (ldr.vport = NIL)
                msg.reply := -1
            ELSE
                ldr.img_num := ldr.img_num + 1
                item_changed := 1
                msg.reply := ldr.img_num
                StrCopy(ldr.img_path, msg.arg)
            ENDIF
        CASE AGSIL_GETIMGNUM
            msg.reply := ldr.img_loaded
        DEFAULT
            msg.reply := -1
    ENDSELECT
    ReplyMsg(msg)
ENDPROC


PROC main() HANDLE
    DEF ldr = NIL:PTR TO loader
    DEF softint = NIL:PTR TO is
    DEF wrapped_code
    DEF port = NIL:PTR TO mp

    ->DEF bmark = NIL:PTR TO benchmark
    DEF il = NIL:PTR TO ilbmloader
    DEF path[PATH_LEN]:STRING
    DEF old_path[PATH_LEN]:STRING
    DEF curr_img = 0

    -> Slideshow vars
    DEF tr:PTR TO timerequest
    DEF timer_msgport:PTR TO mp
    DEF timer_sig = 0
    DEF timer_activated = 0
    DEF slideshow_index = 0
    DEF slideshow_range_size = 0
    DEF i = 0
    DEF indexstring[2]:STRING
    DEF have_indexed_image = 0

    -> Allocate the object that we share with the IRQ handler.
    ldr := NewM(SIZEOF loader, MEMF_PUBLIC OR MEMF_CLEAR)
    ldr.img_path := String(PATH_LEN)

    -> Allocate and configure the soft interrupt structure.
    softint := NewM(SIZEOF is, MEMF_PUBLIC OR MEMF_CLEAR)
    IF (wrapped_code := eCodeSoftInt({softint_handler})) = NIL THEN Raise(ERR_ECODE)
    softint.code := wrapped_code
    softint.data := ldr
    softint.ln.pri := 0

    -> Create a message port and publish it. Don't use createPort() or
    -> CreateMsgPort() since they allocate a signal for a PA_SIGNAL type port.
    -> We need PA_SOFTINT.
    port := NewM(SIZEOF mp, MEMF_PUBLIC OR MEMF_CLEAR)
    ldr.port := port
    newList(port.msglist)
    port.ln.name := AGSIL_PORTNAME
    port.ln.pri := 1
    port.ln.type := NT_MSGPORT
    port.flags := PA_SOFTINT
    port.sigtask := softint
    AddPort(port)

    -> Lower priority to run in the background.
    SetTaskPri(FindTask(NIL), -1)

    -> ILBMLoader object.
    NEW il.init()

    -> Wait until we have received the config from the Menu executable before continuing
    REPEAT
        Delay(1)
    UNTIL ldr.conf <> NIL

    -> Only setup the slideshow if the feature is enabled
    IF ldr.conf.slideshow_delay_secs > 0
        slideshow_index := ldr.conf.slideshow_start_index
        slideshow_range_size := ldr.conf.slideshow_end_index - ldr.conf.slideshow_start_index

        -> Create the slideshow timer
        IF timer_msgport := CreateMsgPort()
            IF tr := CreateIORequest(timer_msgport, SIZEOF timerequest)
                IF OpenDevice('timer.device', UNIT_MICROHZ, tr, 0) = 0
                    timer_sig := Shl(1, timer_msgport.sigbit)
                    tr.io.command := TR_ADDREQUEST
                ELSE
                    DeleteIORequest(tr)
                    Raise(ERR_CREATETIMER)
                ENDIF
            ELSE
                DeleteMsgPort(timer_msgport)
                Raise(ERR_CREATETIMER)
            ENDIF
        ELSE
            Raise(ERR_CREATETIMER)
        ENDIF
    ENDIF

    ->PrintF('AGSImgLoader is waiting for requests on \s, CTRL-C to stop.\n', AGSIL_PORTNAME)
    REPEAT
        -> Ctrl-C.
        IF CtrlC() THEN ldr.status := LDR_QUITTING

        -> Check for slideshow timer event
        IF timer_sig
            WHILE GetMsg(timer_msgport) = tr
                -> Send a new timer request
                tr.time.secs := ldr.conf.slideshow_delay_secs
                SendIO(tr)

                ldr.img_num := ldr.img_num + 1
            ENDWHILE
        ENDIF

        IF curr_img <> ldr.img_num
            Disable()
                curr_img := ldr.img_num
                have_indexed_image := 0

                -> Only look for indexed screenshots if slideshow is enabled
                IF ldr.conf.slideshow_delay_secs > 0
                    -> If the list item has changed, then we
                    -> must reset the start index and timer
                    IF item_changed = 1
                        slideshow_index := ldr.conf.slideshow_start_index

                        -> If the timer has been activated at least
                        -> once, then cancel any pending request
                        IF timer_activated = 1
                            AbortIO(tr) -> end the last timer request
                            WaitIO(tr)  -> wait for it to end
                        ENDIF

                        -> Send a new timer request
                        tr.time.secs := ldr.conf.slideshow_delay_secs
                        SendIO(tr)

                        timer_activated := 1
                        item_changed := 0
                    ENDIF

                    -> Try to find an indexed screenshot
                    FOR i := 0 TO slideshow_range_size
                        StrCopy(path, ldr.img_path)
                        StringF(indexstring, '-\d', slideshow_index)
                        StrAdd(path, indexstring)
                        StrAdd(path, '.iff')

                        slideshow_index := slideshow_index + 1

                        -> Make sure we honour the end index configuration
                        IF slideshow_index = (ldr.conf.slideshow_end_index + 1)
                            slideshow_index := ldr.conf.slideshow_start_index
                        ENDIF

                        -> Check if file exists
                        IF FileLength(path) <> -1
                            have_indexed_image := 1
                        ENDIF

                        -> Exit the for loop if we've found an image
                        EXIT have_indexed_image = 1
                    ENDFOR
                ENDIF

                -> If we haven't got an indexed image, fallback to standard file naming
                IF have_indexed_image = 0
                    StrCopy(path, ldr.img_path)
                    StrAdd(path, '.iff')

                    IF FileLength(path) = -1
                        -> Still didn't find an image file with standard
                        -> naming, so just show the empty screenshot
                        StrCopy(path, ldr.conf.empty_screenshot)
                    ENDIF
                ENDIF
            Enable()

            IF StrCmp(path, old_path)
                ldr.img_loaded := curr_img
            ELSE
                IF il.open(path)
                    ->NEW bmark.init(10)
                    ->bmark.start()
                    IF il.parse_header() = FALSE
                        PrintF('\s failed header parsing\n', path)
                    ELSE
                        fade_out_vport(ldr.vport, ldr.max_colors, 5)

                        -> Erase the background behind any last image displayed
                        SetAPen(ldr.rport, 0)
                        RectFill(ldr.rport,
                                 ldr.conf.screenshot_x,
                                 ldr.conf.screenshot_y,
                                 ldr.conf.screenshot_x + il.last_width,
                                 ldr.conf.screenshot_y + il.last_height)

                        ->il.load_cmap(ldr.vport, ldr.max_colors)
                        ->bmark.mark() -> 0
                        il.load_body(ldr.rport, ldr.conf.screenshot_x, ldr.conf.screenshot_y)
                        ->bmark.mark() -> 1
                        fade_in_vport(il.colormap, ldr.vport, ldr.max_colors, 5)
                        ->PrintF('\s loaded in \d ms\n', path, bmark.msecs(1))
                    ENDIF
                    ldr.img_loaded := curr_img
                    il.close()
                    ->END bmark
                    StrCopy(old_path, path)
                ELSE
                    PrintF('\s not found\n', path)
                ENDIF
            ENDIF
        ELSE
            Delay(1)
        ENDIF

    UNTIL ldr.status = LDR_QUITTING

    IF ldr.conf.slideshow_delay_secs > 0
        -> Cancel any pending timer request
        IF timer_activated = 1
            AbortIO(tr) -> end the last timer request
            WaitIO(tr) -> wait for it to end
        ENDIF

        -> Now close the device and delete the IO request and message ports
        CloseDevice(tr)
        DeleteIORequest(tr)
        DeleteMsgPort(timer_msgport)
    ENDIF

EXCEPT DO
    END il
    IF port
        IF port.ln.name THEN RemPort(port)
        port.sigtask := -1
        port.msglist.head := -1
        Dispose(port)
    ENDIF
    IF softint THEN Dispose(softint)
    IF ldr.img_path THEN DisposeLink(ldr.img_path)
    IF ldr THEN Dispose(ldr)
    SELECT exception
        CASE "MEM"
            PrintF('Out of memory\n')
        CASE ERR_ECODE
            PrintF('eCode() failed\n')
        CASE ERR_CREATEPORT
            PrintF('Couldn''t create "' + AGSIL_PORTNAME + '"\n')
        CASE ILBM_ERROR
            PrintF('\s\n', ilbm_strerror(exceptioninfo))
        CASE ERR_CREATETIMER
            PrintF('Failed to create slideshow timer\n')
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
