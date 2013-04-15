/* Test AGSImgLoader by sending messages. */


OPT OSVERSION=37
OPT PREPROCESS

MODULE 'intuition/intuition'
MODULE 'intuition/screens'
MODULE 'graphics/text'
MODULE '*agsil'


ENUM ERR_NONE, ERR_SCREEN, ERR_WINDOW

PROC main() HANDLE
    DEF am:PTR TO agsil_master
    DEF reply
    
    DEF w = NIL:PTR TO window
    DEF class
    DEF scr:PTR TO screen
    DEF top_border
    DEF left_border
    DEF right_border
    DEF bottom_border
    DEF width
    DEF height
    
    -> Calculate border sizes for Workbench windows.
    IF (scr := LockPubScreen(NIL)) = NIL THEN Throw(AGSIL_ERROR, ERR_SCREEN)
    top_border    := scr.wbortop + scr.font.ysize + 1
    left_border   := scr.wborleft
    right_border  := scr.wborright
    bottom_border := scr.wborbottom
    UnlockPubScreen(NIL, scr)
    
    -> Open window for testing.
    width := 320 + left_border + right_border
    height := 128 + top_border + bottom_border
    IF (w := OpenWindowTagList(NIL,[
        ->WA_CUSTOMSCREEN, s,
        WA_WIDTH, width,
        WA_HEIGHT, height,
        ->WA_TOP, 256,
        WA_TITLE, 'agsimgloader',
        WA_CLOSEGADGET, TRUE,
        ->WA_BORDERLESS, TRUE,
        ->WA_RMBTRAP, TRUE,
        WA_ACTIVATE, FALSE,
        WA_IDCMP, IDCMP_CLOSEWINDOW, ->$268,
        0])) = NIL THEN Raise("WIND")
    
    NEW am.init()
    
    PrintF('SETRPORT($\h[08]): ', w.rport)
    reply := am.send_cmd(AGSIL_SETRPORT, w.rport)
    PrintF('\d\n', reply)
    
    PrintF('SETXY(\d, \d): ', left_border, top_border)
    reply := am.send_cmd(AGSIL_SETXY, Shl(left_border, 16) OR top_border)
    PrintF('\d\n', reply)
    
    PrintF('LOAD(\s): ', 'test128.iff')
    reply := am.send_cmd(AGSIL_LOAD, 'test128.iff')
    PrintF('\d\n', reply)
    
    WHILE (class := WaitIMessage(w)) <> IDCMP_CLOSEWINDOW
    ENDWHILE
    
    PrintF('QUIT(): ')
    reply := am.send_cmd(AGSIL_QUIT, NIL)
    PrintF('\d\n', reply)

EXCEPT DO
    END am
    IF w THEN CloseWindow(w)
    SELECT exception
        CASE ERR_WINDOW
            PrintF('Couldn''t open window\n')
        CASE ERR_SCREEN
            PrintF('Couldn''t lock screen\n')
        CASE AGSIL_ERROR
            PrintF('AGSIL error \d\n', exceptioninfo)
        CASE "MEM"
            PrintF('Out of memory\n')
        DEFAULT
            IF exception
                PrintF('Unknown exception "\s" / $\h[08]\n',
                       [exception, 0],
                       exception)
            ENDIF
    ENDSELECT
ENDPROC
