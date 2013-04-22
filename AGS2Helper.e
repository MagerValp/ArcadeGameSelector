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


ENUM ERR_NONE, ERR_ECODE, ERR_CREATEPORT

ENUM LDR_LOADING, LDR_QUITTING


CONST PATH_LEN=100

OBJECT loader
    port:PTR TO mp
    status:LONG
    rport:PTR TO rastport
    vport:PTR TO viewport
    x:INT
    y:INT
    max_colors:INT
    img_num:LONG
    img_path
    img_loaded:LONG
ENDOBJECT


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
        CASE AGSIL_SETXY
            ldr.x := Shr(msg.arg, 16)
            ldr.y := msg.arg AND $ffff
        CASE AGSIL_SETMAXCOLORS
            ldr.max_colors := msg.arg
        CASE AGSIL_LOAD
            IF (ldr.rport = NIL) OR (ldr.vport = NIL)
                msg.reply := -1
            ELSE
                ldr.img_num := ldr.img_num + 1
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
    
    ->PrintF('AGSImgLoader is waiting for requests on \s, CTRL-C to stop.\n', AGSIL_PORTNAME)
    REPEAT
        -> Ctrl-C.
        IF CtrlC() THEN ldr.status := LDR_QUITTING
        
        IF curr_img <> ldr.img_num
            Disable()
                StrCopy(path, ldr.img_path)
                curr_img := ldr.img_num
            Enable()
            
            IF StrCmp(path, old_path)
                ldr.img_loaded := curr_img
            ELSE
                IF il.open(path)
                    ->NEW bmark.init(10)
                    fade_out_vport(ldr.vport, ldr.max_colors, 5)
                    ->bmark.start()
                    IF il.parse_header() = FALSE
                        PrintF('\s failed header parsing\n', path)
                    ELSE
                        SetAPen(ldr.rport, 0)
                        RectFill(ldr.rport,
                                 ldr.x,
                                 ldr.y,
                                 ldr.x + il.width - 1,
                                 ldr.y + il.height - 1)
                        ->il.load_cmap(ldr.vport, ldr.max_colors)
                        ->bmark.mark() -> 0
                        il.load_body(ldr.rport, ldr.x, ldr.y)
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
    
EXCEPT DO
    END il
    IF port
        IF port.ln.name THEN RemPort(port)
        port.sigtask := -1
        port.msglist.head := -1
        Dispose(port)
    ENDIF
    IF softint THEN Dispose(softint)
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
