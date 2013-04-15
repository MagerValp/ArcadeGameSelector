/* AGSIL contains the control classes for background image loading. */


OPT MODULE
OPT EXPORT
OPT PREPROCESS


MODULE 'exec/memory'
MODULE 'exec/ports'
MODULE 'exec/nodes'
MODULE 'dos/dostags'


CONST AGSIL_ERROR = "AGSI"
ENUM AGSIL_ERR_FINDPORT = 1, AGSIL_ERR_CREATEPORT, AGSIL_ERR_START

EXPORT PROC agsil_strerror(num:LONG) IS ListItem([
        'FindPort failed',
        'CreatePort failed',
        'Couldn''t start image loader'
    ], num - 1)


#define AGSIL_PORTNAME 'agsilport'

ENUM AGSIL_QUIT,
     AGSIL_SETRPORT,
     AGSIL_SETVPORT,
     AGSIL_SETXY,
     AGSIL_LOAD,
     AGSIL_GETIMGNUM

OBJECT agsil_msg
    msg:mn
    action:LONG
    arg:LONG
    reply:LONG
ENDOBJECT


OBJECT agsil_master
    replyport:PTR TO mp
    msg:PTR TO agsil_msg
    send_quit   -> Set to TRUE if we should attempt to send an AGSIL_QUIT
ENDOBJECT       -> message in end().

PROC init() OF agsil_master
    self.replyport := CreateMsgPort()
    IF self.replyport = NIL THEN Throw(AGSIL_ERROR, AGSIL_ERR_CREATEPORT)
    self.msg := NewM(SIZEOF agsil_msg, MEMF_PUBLIC OR MEMF_CLEAR)
    self.msg.msg.ln.type := NT_MESSAGE
    self.msg.msg.length := SIZEOF agsil_msg
    self.msg.msg.replyport := self.replyport
    self.send_quit := TRUE
ENDPROC

PROC end() OF agsil_master
    DEF port:PTR TO mp
    
    IF self.send_quit
        self.msg.action := AGSIL_QUIT
        self.msg.arg := NIL
        Forbid()
            port := FindPort(AGSIL_PORTNAME)
            IF port THEN PutMsg(port, self.msg)
        Permit()
        IF port
            WaitPort(self.replyport)
            GetMsg(self.replyport)
        ENDIF
    ENDIF
    IF self.msg THEN Dispose(self.msg)
    IF self.replyport THEN DeleteMsgPort(self.replyport)
ENDPROC

PROC start() OF agsil_master
    DEF result
    DEF console
    
    console := Open('CON:0/40/640/150/irqimgloader/auto/close/wait', OLDFILE)
    result := SystemTagList('AGS:irqimgloader', [
        SYS_ASYNCH, TRUE,
        SYS_INPUT, console,
        SYS_OUTPUT, NIL,
        0])
    IF result = -1
        Close(console)
        Throw(AGSIL_ERROR, AGSIL_ERR_START)
    ENDIF
ENDPROC

PROC wait_port() OF agsil_master
    DEF count = 0
    
    REPEAT
        IF FindPort(AGSIL_PORTNAME)
            RETURN
        ENDIF
        Delay(1)
    UNTIL count++ = 250
    -> Throw an error if it takes more than 5 seconds for the agsil port to
    -> appear.
    Throw(AGSIL_ERROR, AGSIL_ERR_START)
ENDPROC

PROC send_cmd(action:LONG, arg:LONG) OF agsil_master
    DEF port:PTR TO mp
    DEF reply:PTR TO agsil_msg
    
    self.msg.action := action
    IF action = AGSIL_QUIT
        self.send_quit := FALSE -> QUIT has already been sent, no need for
    ENDIF                       -> end() to do it.
    self.msg.arg := arg
    Forbid()
        port := FindPort(AGSIL_PORTNAME)
        IF port THEN PutMsg(port, self.msg)
    Permit()
    IF port = NIL THEN Throw(AGSIL_ERROR, AGSIL_ERR_FINDPORT)
    WaitPort(self.replyport)
    IF (reply := GetMsg(self.replyport)) = NIL
        self.msg.reply := NIL
    ENDIF
ENDPROC self.msg.reply

PROC stop() OF agsil_master IS self.send_cmd(AGSIL_QUIT, NIL)

PROC wait_load(img_num:LONG) OF agsil_master
    DEF num
    
    WHILE (num := self.send_cmd(AGSIL_GETIMGNUM, NIL)) <> img_num
        Delay(1)
    ENDWHILE
ENDPROC
