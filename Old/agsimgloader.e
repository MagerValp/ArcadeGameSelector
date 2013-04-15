/* AGSImgLoader - Background loading of images for AGS. */


OPT OSVERSION=37
OPT PREPROCESS

MODULE 'exec/ports'
MODULE 'exec/nodes'
MODULE 'dos/dos'
MODULE 'graphics/rastport'
MODULE '*benchmark'
MODULE '*agsil'
MODULE '*ilbmloader'


ENUM ERR_NONE, ERR_CREATEPORT


PROC load_image(il:PTR TO ilbmloader,
                name:PTR TO CHAR,
                rport:PTR TO rastport,
                x:LONG,
                y:LONG)
    DEF bmark = NIL:PTR TO benchmark
    
    NEW bmark.init(10)
    PrintF('Loading \s\n', name)
    bmark.start()
    il.open(name)
    bmark.mark() -> 0
    il.parse_header()
    bmark.mark() -> 1
    il.load_body(rport, x, y)
    bmark.mark() -> 2
    il.close()
    PrintF('Open IFF:  \d[4] ms\n', bmark.msecs(0))
    PrintF('Parse IFF: \d[4] ms\n', bmark.msecs(1) - bmark.msecs(0))
    PrintF('Load BODY: \d[4] ms\n', bmark.msecs(2) - bmark.msecs(1))
    END bmark
ENDPROC


PROC main() HANDLE
    DEF port = NIL:PTR TO mp
    DEF msg:PTR TO agsil_msg
    DEF portsig
    DEF breaksig
    DEF signal
    DEF abort = FALSE
    DEF action
    DEF il = NIL:PTR TO ilbmloader
    DEF rport = NIL:PTR TO rastport
    DEF x = 0
    DEF y = 0
    DEF img_to_load:PTR TO CHAR
    
    -> ILBMLoader object.
    NEW il.init()
    
    -> Create a message port and publish it.
    IF (port := CreateMsgPort()) = NIL THEN Raise(ERR_CREATEPORT)
    port.ln.name := AGSIL_PORTNAME
    port.ln.pri := 1
    AddPort(port)
    
    -> Get signal masks for Wait().
    portsig := Shl(1, port.sigbit)
    breaksig := SIGBREAKF_CTRL_C
    
    -> Lower priority to run in the background.
    SetTaskPri(FindTask(NIL), -1)
    
    PrintF('AGSImgLoader is waiting for requests on \s, CTRL-C to stop.\n', AGSIL_PORTNAME)
    REPEAT
        -> Wait for a message or break signal.
        signal := Wait(portsig OR breaksig)
        
        -> Our message port received a message.
        IF signal AND portsig
            WHILE msg := GetMsg(port)
                action := msg.action
                SELECT action
                    CASE AGSIL_QUIT
                        PrintF('QUIT()\n')
                        abort := TRUE
                        msg.reply := AGSIL_OK
                    CASE AGSIL_SETRPORT
                        PrintF('SETRPORT($\h[08])\n', msg.arg)
                        rport := msg.arg
                        msg.reply := AGSIL_OK
                    CASE AGSIL_SETXY
                        x := Shr(msg.arg, 16)
                        y := msg.arg AND $ffff
                        PrintF('SETXY(\d, \d)\n', x, y)
                        msg.reply := AGSIL_OK
                    CASE AGSIL_LOAD
                        PrintF('LOAD(\s)\n', msg.arg)
                        IF rport = NIL
                            PrintF('No raster port set!\n')
                            msg.reply := AGSIL_ERROR
                        ELSE
                            msg.reply := AGSIL_OK
                            img_to_load := msg.arg
                        ENDIF
                    DEFAULT
                        PrintF('Unknown action $\h\n', action)
                ENDSELECT
                ReplyMsg(msg)
            ENDWHILE
        ENDIF
        
        -> Ctrl-C.
        IF signal AND breaksig
            abort := TRUE
        ENDIF
        
        IF img_to_load
            load_image(il, img_to_load, rport, x, y)
            img_to_load := NIL
        ENDIF
        
    UNTIL abort
    
EXCEPT DO
    END il
    IF port
        -> Empty the message queue before deleting it.
        PrintF('Flushing and deleting \s.\n', AGSIL_PORTNAME)
        WHILE msg := GetMsg(port) DO ReplyMsg(msg)
        IF port.ln.name THEN RemPort(port)
        DeleteMsgPort(port)
    ENDIF
    SELECT exception
        CASE ERR_CREATEPORT
            PrintF('Couldn''t create "\s"\n', AGSIL_PORTNAME)
        CASE ILBM_ERROR
            PrintF('ILBMLoader error \d\n', exceptioninfo)
        DEFAULT
            IF exception
                PrintF('Unknown exception "\s" / $\h[08]\n',
                       [exception, 0],
                       exception)
            ENDIF
    ENDSELECT
ENDPROC
