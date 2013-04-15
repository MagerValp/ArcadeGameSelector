OPT MODULE
OPT EXPORT
OPT PREPROCESS


CONST CHUNKBUFSIZE = 4096

OBJECT chunkbuffer
    iff:PTR TO iffhandle
    data_left:LONG
    buf_size:LONG
    buf_ctr:LONG
    buf[CHUNKBUFSIZE]:ARRAY OF CHAR
ENDOBJECT

PROC init(iff:PTR TO iffhandle) OF chunkbuffer
    DEF ctxnode:PTR TO contextnode
    self.iff := iff
    ctxnode := CurrentChunk(iff)
    ->Vprintf('"%s" / "%s", size = %ld\n', [[ctxnode.id, 0], [ctxnode.type, 0], ctxnode.size])
    self.data_left := ctxnode.size
    self.buf_size := 0
    self.buf_ctr := 0
ENDPROC


PROC getbyte() OF chunkbuffer
    DEF byte
    DEF len
    
    IF self.buf_ctr >= self.buf_size
        len := IF self.data_left < CHUNKBUFSIZE THEN self.data_left ELSE CHUNKBUFSIZE
        ->PrintF('Reading \d bytes into buffer\n', len)
        self.buf_size := ReadChunkBytes(self.iff, self.buf, len)
        IF self.buf_size < 0
            ->PrintF('ReadChunkBytes() = \d\n', self.buf_size)
            Raise("IOER")
        ->ELSE
        ->    PrintF('Read \d bytes\n', self.buf_size)
        ENDIF
        self.buf_ctr := 0
        self.data_left := self.data_left - len
    ENDIF
    byte := self.buf[self.buf_ctr]
    self.buf_ctr := self.buf_ctr + 1
    ->byte := self.buf_ctr AND $ff
ENDPROC byte
/*
PROC getbytes(nbytes:LONG, dest:PTR TO CHAR) OF chunkbuffer
ENDPROC
*/
