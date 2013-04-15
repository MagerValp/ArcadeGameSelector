OPT PREPROCESS,REG=3

MODULE 'intuition/screens', 'intuition/intuition', 'graphics/modeid',
       'dos/dos', 'graphics/rastport', 'graphics/text', 'lowlevel',
       'libraries/lowlevel', 'tools/ilbm', 'tools/ilbmdefs', 'exec/memory',
       'graphics/gfx'

DEF tt[256]:ARRAY OF CHAR,ct[256]:ARRAY OF CHAR

OBJECT chooser
    active
    nchoices
    offset
    height
    choice:PTR TO CHAR
ENDOBJECT

PROC clear() OF chooser
    DEF i

    self.choice:=AllocMem(65536,MEMF_CLEAR)
    IF self.choice=NIL THEN Raise("MEM")
    FOR i:=0 TO 65535
        self.choice[i]:=0
    ENDFOR
    self.nchoices:=0
    self.offset:=0
    self.height:=0
    self.active:=0
ENDPROC

PROC end() OF chooser
    IF self.choice THEN FreeMem(self.choice,65536)
ENDPROC

PROC sort() OF chooser
    DEF i,j,a:PTR TO CHAR,key[32]:ARRAY OF CHAR

    a:=self.choice
    IF self.nchoices>1
        FOR j:=1 TO self.nchoices-1
            CopyMem(a+(j*32),key,32)
            i:=j-1
            WHILE (i>=0) AND (compare(a+(i*32),key)>0)
                CopyMem(a+(i*32),a+((i+1)*32),32)
                i--
            ENDWHILE
            CopyMem(key,a+((i+1)*32),32)
        ENDFOR
    ENDIF
ENDPROC

PROC compare(a:PTR TO CHAR,b:PTR TO CHAR)
    DEF aa[32]:ARRAY OF CHAR,bb[32]:ARRAY OF CHAR,i

    i:=0 ; WHILE a[i]<>0 ; aa[i]:=ct[a[i]] ; i++ ; ENDWHILE
    i:=0 ; WHILE b[i]<>0 ; bb[i]:=ct[b[i]] ; i++ ; ENDWHILE
    i:=0
    LOOP
        IF aa[i]>bb[i] THEN RETURN 1
        IF aa[i]<bb[i] THEN RETURN -1
        IF (aa[i]=0) OR (bb[i]=0) THEN RETURN 0
        i++
    ENDLOOP
ENDPROC

PROC render(w:PTR TO window) OF chooser
    DEF i,p,line[24]:ARRAY OF CHAR,fh=NIL,txt[40]:STRING,buf[492]:ARRAY OF CHAR,
    info[480]:ARRAY OF CHAR,len,l

    SetAPen(w.rport,255)
    SetBPen(w.rport,254)
    FOR i:=0 TO self.height-1
        FOR p:=0 TO 23
            line[p]:=tt[self.choice[((self.offset+i)*32)+p]]
        ENDFOR
        IF self.active=i THEN SetDrMd(w.rport,RP_INVERSVID OR RP_JAM2) ELSE SetDrMd(w.rport,RP_JAM2)
        Move(w.rport,16,8+w.rport.font.baseline+(8*i))
        Text(w.rport,line,24)
    ENDFOR

    FOR i:=0 TO 479
        info[i]:=" "
    ENDFOR

    StrCopy(txt,'AGS:')
    StrAdd(txt,self.choice+((self.offset+self.active)*32))
    StrAdd(txt,'.txt')
    IF (fh:=Open(txt,MODE_OLDFILE))<>NIL
        len:=Read(fh,buf,492)
        Close(fh)
        IF len>0
            l:=0
            p:=0
            i:=0
            WHILE i<len
                IF buf[i]<32
                    l++
                    IF l=12
                        i:=len
                    ELSE
                        i++
                        p:=0
                    ENDIF
                ELSE
                    info[(l*40)+p++]:=buf[i++]
                    IF p>39
                        l++
                        IF l=12
                            i:=len
                        ELSE
                            p:=0
                            REPEAT ; UNTIL (buf[i++]<32) OR (i>=len)
                        ENDIF
                    ENDIF
                ENDIF
            ENDWHILE
        ENDIF
    ENDIF

    SetDrMd(w.rport,RP_JAM2)
    Move(w.rport,304,144+w.rport.font.baseline)
    Text(w.rport,info,40)
    FOR i:=1 TO 11
        Move(w.rport,304,152+w.rport.font.baseline+(8*i))
        Text(w.rport,info+(i*40),40)
    ENDFOR
ENDPROC

PROC main() HANDLE
    DEF s=NIL:PTR TO screen,w=NIL:PTR TO window,lock=NIL,
            menu:chooser,portstate,fb:fileinfoblock,len,i,
            upctr=0,downctr=0,ssctr=0,font:PTR TO textfont,ta:textattr,
            mouseptr[256]:ARRAY OF CHAR

    DeleteFile('AGS:.run')
    FOR i:=0 TO 255
        tt[i]:=i
        ct[i]:=i
        mouseptr[i]:=0
    ENDFOR
    tt[0]:=" "
    tt["_"]:=" "
    ct["_"]:=" "
    FOR i:=65 TO 90
        ct[i]:=i+32
    ENDFOR
    FOR i:=192 TO 222
        ct[i]:=i+32
    ENDFOR
    ct[215]:=215

    IF (lowlevelbase:=OpenLibrary('lowlevel.library',0))=NIL THEN Raise("LOWL")

    IF SetJoyPortAttrsA(1,[SJA_TYPE,SJA_TYPE_JOYSTK,0])=FALSE
        Raise("JATR")
    ENDIF
    
    NEW menu.clear()
    IF (lock:=Lock('AGS:',ACCESS_READ))=FALSE
        Raise("LOCK")
    ENDIF
    IF Examine(lock,fb)=NIL
        Raise("EXAM")
    ENDIF
    WHILE ExNext(lock,fb)<>FALSE
        len:=StrLen(fb.filename)
        IF (len>6) AND (len<=30)
            IF InStr(fb.filename,'.start')=(len-6)
                FOR i:=0 TO len-7
                    menu.choice[menu.nchoices*32+i]:=fb.filename[i]
                ENDFOR
                menu.nchoices:=menu.nchoices+1
            ENDIF
        ENDIF
    ENDWHILE

    IF menu.nchoices=0 THEN Raise("NONE")

    menu.sort()

    menu.active:=0
    IF menu.nchoices<30
        menu.height:=menu.nchoices
    ELSE
        menu.height:=30
    ENDIF

    IF (s:=OpenScreenTagList(NIL,[
            SA_WIDTH,640,
            SA_HEIGHT,256,
            SA_DEPTH,8,
            SA_DISPLAYID,HIRES_KEY,
->            SA_DISPLAYID,$50041000,
            SA_DRAGGABLE,FALSE,
            SA_SHOWTITLE,FALSE,
            0]))=NIL THEN Raise("SCRN")
    IF (w:=OpenWindowTagList(NIL,[
            WA_CUSTOMSCREEN,s,
            WA_WIDTH,640,
            WA_HEIGHT,256,
            WA_TITLE,0,
            WA_CLOSEGADGET,FALSE,
            WA_BORDERLESS,TRUE,
            WA_RMBTRAP,TRUE,
            WA_ACTIVATE,TRUE,
            0]))=NIL THEN Raise("WIND")

    SetPointer(w,mouseptr,1,1,0,0)

    ta.name:='topaz.font'
    ta.ysize:=8
    ta.style:=0
    ta.flags:=0
    IF (font:=OpenFont(ta))=NIL THEN Raise("FONT")
    SetFont(w.rport,font)

    loadbkg(w)
    menu.render(w)

    LOOP
        WaitTOF()
        IF ((portstate:=ReadJoyPort(1))=JP_TYPE_NOTAVAIL)
            Raise("JTYP")
        ENDIF

        IF (portstate AND JPF_BUTTON_RED)
            choose(menu.active+menu.offset,menu)
            Raise("QUIT")
        ELSEIF (portstate AND JPF_BUTTON_BLUE)
            Raise("QUIT")
        ENDIF

        IF (portstate AND JPF_JOY_UP)
            IF (upctr=0) OR (upctr>8)
                IF menu.active>0
                    menu.active:=menu.active-1
                    menu.render(w)
                    ssctr:=0
                ELSEIF menu.offset>0
                    menu.offset:=menu.offset-1
                    menu.render(w)
                ENDIF
            ENDIF
            upctr++
        ELSE
            upctr:=0
        ENDIF

        IF (portstate AND JPF_JOY_DOWN)
            IF (downctr=0) OR (downctr>8)
                IF menu.active<(menu.height-1)
                    menu.active:=menu.active+1
                    menu.render(w)
                    ssctr:=0
                ELSEIF (menu.active+menu.offset)<(menu.nchoices-1)
                    menu.offset:=menu.offset+1
                    menu.render(w)
                    ssctr:=0
                ENDIF
            ENDIF
            downctr++
        ELSE
            downctr:=0
        ENDIF

        IF ssctr++=8
            menu.loadss(w)
        ENDIF

    ENDLOOP


EXCEPT DO
    IF font THEN CloseFont(font)
    IF lock THEN UnLock(lock)
    IF w THEN CloseWindow(w)
    IF s THEN CloseScreen(s)
    SetJoyPortAttrsA(1, [SJA_REINITIALIZE,0,0])
    END menu
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

PROC choose(i,menu:PTR TO chooser)
    DEF name[1024]:STRING

    StrCopy(name,'AGS:')
    StrAdd(name,menu.choice+(i*32))
    StrAdd(name,'.start')
    copy(name,'AGS:.run')
ENDPROC

PROC copy(infile:PTR TO CHAR,outfile:PTR TO CHAR) HANDLE
    DEF len,if=NIL,of=NIL,buf[512]:ARRAY OF CHAR

    IF (if:=Open(infile,MODE_OLDFILE))=NIL THEN Raise("INFL")
    IF (of:=Open(outfile,MODE_NEWFILE))=NIL THEN Raise("OUTF")
    WHILE (len:=Read(if,buf,512))>0
        IF Write(of,buf,len)<>len THEN Raise("WERR")
    ENDWHILE
    Raise("QUIT")
EXCEPT DO
    IF if THEN Close(if)
    IF of THEN Close(of)
    ReThrow()
ENDPROC

PROC loadbkg(w:PTR TO window) HANDLE
    DEF pic=NIL,bm=NIL:PTR TO bitmap,pi:PTR TO picinfo,r,g,b

    IF (pic:=ilbm_New('AGS:SelectorBKG.iff',ILBMNF_COLOURS32))=NIL THEN Raise("BKGN")
    IF ilbm_LoadPicture(pic,[ILBML_GETBITMAP,{bm},0])<>0 THEN Raise("BKGL")
    pi:=ilbm_PictureInfo(pic)
    IF pi.pal32<>NIL
        LoadRGB32(w.wscreen.viewport,pi.pal32)
    ELSE
        FOR b:=0 TO 5
            FOR g:=0 TO 5
                FOR r:=0 TO 5
                    SetRGB4(w.wscreen.viewport,(r*36)+(g*6)+b,r*3,g*3,b*3)
                ENDFOR
            ENDFOR
        ENDFOR
        SetRGB4(w.wscreen.viewport,255,13,14,15)
        SetRGB4(w.wscreen.viewport,254,3,4,5)
    ENDIF
    BltBitMapRastPort(bm,0,0,w.rport,0,0,640,256,$0c0)

    Raise("OK")
EXCEPT DO
    IF bm THEN ilbm_FreeBitMap(bm)
    IF pic THEN ilbm_Dispose(pic)
    SELECT exception
        CASE "OK"
        CASE "BKGN" ; PrintF('Couldn''t open background image\n')
        CASE "BKGL" ; PrintF('Couldn''t load background image\n')
        DEFAULT
            PrintF('Unknown loadbkg exception: \z\h[8]\n',exception)
    ENDSELECT
ENDPROC

PROC loadss(w:PTR TO window) OF chooser HANDLE
    DEF pic=NIL,bm=NIL:PTR TO bitmap,pi:PTR TO picinfo,picname[32]:STRING,
            b:PTR TO bmhd

    StrCopy(picname,'AGS:')
    StrAdd(picname,self.choice+((self.active+self.offset)*32))
    StrAdd(picname,'.iff')
    IF (pic:=ilbm_New(picname,ILBMNF_COLOURS32))=NIL THEN Raise("NEW")
    IF ilbm_LoadPicture(pic,[ILBML_GETBITMAP,{bm},0])<>0 THEN Raise("LOAD")
    pi:=ilbm_PictureInfo(pic)
    b:=pi.bmhd
    IF (b.w<>320) OR (b.h<>128) THEN Raise("SIZE")
    IF pi.pal32<>NIL
->        LoadRGB32(w.wscreen.viewport,pi.pal32)
    ENDIF
    BltBitMapRastPort(bm,0,0,w.rport,304,8,320,128,$0c0)

    Raise("OK")
EXCEPT DO
    IF bm THEN ilbm_FreeBitMap(bm)
    IF pic THEN ilbm_Dispose(pic)
    SELECT exception
        CASE "OK"
        DEFAULT
            SetAPen(w.rport,254)
            BltPattern(w.rport,NIL,304,8,304+319,8+127,0)
    ENDSELECT
ENDPROC
