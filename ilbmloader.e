/* Class for loading ILBM files. */


OPT MODULE
OPT PREPROCESS


MODULE 'graphics/gfx'
MODULE 'graphics/rastport'
MODULE 'graphics/view'
MODULE 'iffparse'
MODULE 'libraries/iffparse'
MODULE '*rgbcolor'


EXPORT CONST ILBM_ERROR = "ILBM"
EXPORT ENUM ERR_IFF_LIBRARY = 1,
            ERR_IFF_ALLOCIFF,
            ERR_IFF_ALREADYOPEN,
            ERR_IFF_OPENFILE,
            ERR_IFF_OPENIFF,
            ERR_IFF_ALLOCRASTER

EXPORT PROC ilbm_strerror(num:LONG) IS ListItem([
        'ERR_IFF_LIBRARY',
        'ERR_IFF_ALLOCIFF',
        'ERR_IFF_ALREADYOPEN',
        'ERR_IFF_OPENFILE',
        'ERR_IFF_OPENIFF',
        'ERR_IFF_ALLOCRASTER'
    ], num - 1)

ENUM COMPRESSION_NONE, COMPRESSION_BYTERUN1
ENUM MASK_NONE, MASK_HASMASK, MASK_HASTRANSPARENTCOLOR, MASK_LASSO

OBJECT ilbm_bmhd
    w:INT
    h:INT
    x:INT
    y:INT
    nplanes:CHAR
    masking:CHAR
    compression:CHAR
    ->pad:CHAR
    transparentcolor:INT
    xaspect:CHAR
    yaspect:CHAR
    pagewidth:INT
    pageheight:INT
ENDOBJECT

EXPORT OBJECT ilbmloader
    iff:PTR TO iffhandle

    width:INT
    last_width:INT
    height:INT
    last_height:INT
    depth:CHAR
    last_depth:CHAR
    masking:CHAR
    compression:CHAR

    ncolors:LONG
    colormap:PTR TO rgbcolor

    mode:LONG

    is_open:INT

    bm:PTR TO bitmap
    planeptr:PTR TO CHAR
ENDOBJECT

EXPORT PROC init() OF ilbmloader
    DEF iff:PTR TO iffhandle

    -> Read ILBM image using iffparse.library.
    IF (iffparsebase := OpenLibrary('iffparse.library', 0)) = NIL THEN Throw(ILBM_ERROR, ERR_IFF_LIBRARY)
    -> Allocate IFF handle and prepare it for DOS streams.
    IF (iff := AllocIFF()) = NIL THEN Throw(ILBM_ERROR, ERR_IFF_ALLOCIFF)
    self.iff := iff
    InitIFFasDOS(self.iff)
ENDPROC

PROC end() OF ilbmloader
    IF self.is_open THEN self.close()
    IF self.iff THEN FreeIFF(self.iff)
    IF iffparsebase THEN CloseLibrary(iffparsebase)
    IF self.bm THEN self.free_in_memory_bitmap()
ENDPROC

PROC free_in_memory_bitmap() OF ilbmloader
    IF KickVersion(39)
        FreeBitMap(self.bm)
    ELSE
        FreeRaster(self.planeptr, self.last_width * self.last_depth, self.last_height)
        END self.bm
    ENDIF

    self.bm := NIL
ENDPROC

-> Open an IFF image for reading.
EXPORT PROC open(name:PTR TO CHAR) OF ilbmloader
    DEF fh

    IF self.is_open THEN Throw(ILBM_ERROR, ERR_IFF_ALREADYOPEN)

    IF (fh := Open(name, OLDFILE)) = NIL
        -> THEN Throw(ILBM_ERROR, ERR_IFF_OPENFILE)
        RETURN FALSE
    ENDIF
    self.iff.stream := fh

    IF OpenIFF(self.iff, IFFF_READ)
        Close(fh)
        self.iff.stream := NIL
        Throw(ILBM_ERROR, ERR_IFF_OPENIFF)
    ENDIF

    self.is_open := TRUE
ENDPROC TRUE

EXPORT PROC close() OF ilbmloader
    IF self.is_open
        IF self.colormap THEN END self.colormap[self.ncolors]
        Close(self.iff.stream)
        CloseIFF(self.iff)
        self.is_open := FALSE
    ENDIF
ENDPROC

-> Parse image header.
EXPORT PROC parse_header() OF ilbmloader
    DEF bmhd:PTR TO ilbm_bmhd
    DEF sp:PTR TO storedproperty
    DEF cmap:PTR TO CHAR
    DEF ret
    DEF i

    PropChunk(self.iff, "ILBM", "BMHD")
    PropChunk(self.iff, "ILBM", "CMAP")
    PropChunk(self.iff, "ILBM", "CAMG")
    StopChunk(self.iff, "ILBM", "BODY")
    ret := ParseIFF(self.iff, IFFPARSE_SCAN)
    ->PrintF('ParseIFF returned \d\n', ret)

    IF (sp := FindProp(self.iff, "ILBM", "BMHD")) = NIL THEN RETURN FALSE
    -> Throw(ILBM_ERROR, ERR_IFF_NOBMHD)
    bmhd := sp.data
    ->PrintF('w = \d, h = \d\n', bmhd.w, bmhd.h)
    ->PrintF('x = \d, y = \d\n', bmhd.x, bmhd.y)
    ->PrintF('nplanes = \d\n', bmhd.nplanes)
    ->PrintF('masking = \d\n', bmhd.masking)
    ->PrintF('compression = \d\n', bmhd.compression)
    ->PrintF('transparentcolor = \d\n', bmhd.transparentcolor)
    ->PrintF('xaspect = \d, yaspect = \d\n', bmhd.xaspect, bmhd.yaspect)
    ->PrintF('pagewidth = \d, pageheight = \d\n', bmhd.pagewidth, bmhd.pageheight)
    self.width := bmhd.w
    self.height := bmhd.h
    self.depth := bmhd.nplanes
    self.masking := bmhd.masking
    self.compression := bmhd.compression
    ->self.transparentcolor := bmhd.transparentcolor

    IF (sp := FindProp(self.iff, "ILBM", "CMAP")) <> NIL
        self.ncolors := Min(sp.size / 3, Shl(1, self.depth))
        NEW self.colormap[self.ncolors]
        cmap := sp.data
        FOR i := 0 TO self.ncolors - 1
            self.colormap[i].r := cmap[]++
            self.colormap[i].g := cmap[]++
            self.colormap[i].b := cmap[]++
        ENDFOR
    ENDIF

    IF (sp := FindProp(self.iff, "ILBM", "CAMG")) <> NIL
        self.mode := Long(sp.data)
    ENDIF
ENDPROC TRUE

-> Load colormap into viewport.
EXPORT PROC load_cmap(vport:PTR TO viewport, max_colors:LONG) OF ilbmloader
    DEF colors32:PTR TO LONG
    DEF colors4:PTR TO INT
    DEF i
    DEF offset
    DEF ncolors

    ncolors := Min(self.ncolors, max_colors)
    IF KickVersion(39)
        NEW colors32[(ncolors * 3) + 2]
        colors32[0] := Shl(ncolors, 16)
        colors32[(ncolors * 3) + 1] := 0
        FOR i := 0 TO ncolors - 1
            offset := (i * 3) + 1
            colors32[offset]     := Shl(self.colormap[i].r, 24)
            colors32[offset + 1] := Shl(self.colormap[i].g, 24)
            colors32[offset + 2] := Shl(self.colormap[i].b, 24)
        ENDFOR
        LoadRGB32(vport, colors32)
        END colors32[(ncolors * 3) + 2]
    ELSE
        NEW colors4[ncolors]
        FOR i := 0 TO ncolors - 1
            colors4[i] := Shl(self.colormap[i].r AND $f0, 4) OR (self.colormap[i].g AND $f0) OR Shr(self.colormap[i].b, 4)
        ENDFOR
        LoadRGB4(vport, colors4, ncolors)
        END colors4[ncolors]
    ENDIF
ENDPROC

-> Load image body into raster port at x, y.
EXPORT PROC load_body(rport:PTR TO rastport, x:LONG, y:LONG) OF ilbmloader
    DEF ctxnode:PTR TO contextnode
    DEF cdata:PTR TO CHAR
    DEF i

    IF self.bm AND (self.width <> self.last_width OR self.height <> self.last_height OR self.depth <> self.last_depth)
        -> We have a preallocated in-memory bitmap, but it's not the right size or
        -> depth for this new image, so free it so that it'll be reallocated below
        self.free_in_memory_bitmap()
    ENDIF

    IF self.bm = NIL
        -> Allocate an in-memory bitmap to be used for blitting.
        IF KickVersion(39)
            self.bm := AllocBitMap(self.width, self.height, self.depth, BMF_INTERLEAVED, rport)
        ELSE
            -> For Kickstart 2.0 we have to allocate and initialize the bitmap manually.
            NEW self.bm
            -> Width has to be multiplied by depth to match AllocBitMap.
            InitBitMap(self.bm, self.depth, self.width * self.depth, self.height)
            -> Width also has to be multiplied by depth here too.
            self.planeptr := AllocRaster(self.width * self.depth, self.height)
            IF self.planeptr = NIL
                END self.bm
                Throw(ILBM_ERROR, ERR_IFF_ALLOCRASTER)
            ENDIF
            -> Assign each line to the bm.planes. This emulates BMF_INTERLEAVED.
            FOR i := 0 TO self.bm.depth - 1
                self.bm.planes[i] := self.planeptr + ((self.bm.bytesperrow / self.bm.depth) * i)
            ENDFOR
        ENDIF
    ENDIF

    -> Keep a copy of the width, height and depth of this image
    -> which will be checked and used if we load another image
    self.last_width := self.width
    self.last_height := self.height
    self.last_depth := self.depth

    /*
    PrintF('bm = $\h[08]\n', bm)
    PrintF('bm.bytesperrow = \d\n', bm.bytesperrow)
    PrintF('bm.rows = \d\n', bm.rows)
    PrintF('bm.flags = \d\n', bm.flags)
    PrintF('bm.depth = \d\n', bm.depth)
    FOR i := 0 TO bm.depth - 1
        PrintF('bm.planes[\d] = $\h[08]\n', i, bm.planes[i])
    ENDFOR
    */
    -> Load the chunk data.
    ctxnode := CurrentChunk(self.iff)

    -> Check if image is RLE compressed
    IF self.compression = COMPRESSION_BYTERUN1
        NEW cdata[ctxnode.size]
        ReadChunkBytes(self.iff, cdata, ctxnode.size)
        -> Unpack and blit into raster port.
        self.ilbm_body_unpack(cdata, self.bm, rport, x, y)
        -> Free chunk data.
        END cdata[ctxnode.size]
    ELSE
        -> Read the data directly into the bitmap (image must not be compressed)
        ReadChunkBytes(self.iff, self.bm.planes[0], ctxnode.size)
        -> Blit into raster port.
        BltBitMapRastPort(self.bm, 0, 0, rport, x, y, self.width, self.height, $0c0)
    ENDIF
ENDPROC

-> Optimized loop for decoding ilbm body.
PROC ilbm_body_unpack(cdata:PTR TO CHAR,
                      bm:PTR TO bitmap,
                      rport:PTR TO rastport,
                      x:LONG,
                      y:LONG) OF ilbmloader
    DEF i:REG
    DEF buf_ptr:REG PTR TO CHAR
    DEF cmd:REG
    DEF byte:REG
    DEF line_buffer = NIL:PTR TO CHAR
    DEF line
    DEF bytes_per_line
    DEF bytes_left
    DEF file_depth

    -> If there is a bitmap mask there's an extra bitplane for each line.
    file_depth := self.depth + (IF self.masking = MASK_HASMASK THEN 1 ELSE 0)
    bytes_per_line := Shl(Shr(self.width + 15, 4), 1) * file_depth
    -> Allocate a buffer to hold one unpacked line.
    NEW line_buffer[bytes_per_line]
    -> Unpack image line by line.
    FOR line := 0 TO self.height - 1
        buf_ptr := line_buffer
        bytes_left := bytes_per_line
        REPEAT
            cmd := cdata[]++
            SELECT 256 OF cmd
                CASE $80
                    -> $80 bytes are ignored.
                CASE $81 TO $ff
                    -> -1 to -127 => repeat next byte -n + 1 times
                    byte := cdata[]++
                    cmd := 256 - cmd
                    FOR i := 0 TO cmd
                        buf_ptr[]++ := byte
                    ENDFOR
                    bytes_left := bytes_left - (cmd + 1)
                DEFAULT
                    FOR i := 0 TO cmd
                        buf_ptr[]++ := cdata[]++
                    ENDFOR
                    bytes_left := bytes_left - (cmd + 1)
            ENDSELECT
        UNTIL bytes_left < 1

        CopyMem(line_buffer, bm.planes[0] + (bm.bytesperrow * line), bm.bytesperrow)
    ENDFOR

    -> Now that the bitmap is completely unpacked into memory, blit it to the raster port
    BltBitMapRastPort(bm, 0, 0, rport, x, y, self.width, self.height, $0c0)

    END line_buffer
ENDPROC
