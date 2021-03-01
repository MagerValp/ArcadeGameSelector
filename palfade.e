/* Module for fading palettes. */


OPT MODULE
OPT PREPROCESS


->MODULE 'graphics/gfx'
->MODULE 'graphics/rastport'
MODULE 'graphics/view'
MODULE '*rgbcolor'


-> Fade viewport palette to black.
EXPORT PROC fade_out_vport(vport:PTR TO viewport, max_colors:LONG, steps:LONG)
    DEF ncolors
    DEF ncolors32
    DEF color32 = NIL:PTR TO LONG
    DEF fade32 = NIL:PTR TO LONG
    DEF color4 = NIL:PTR TO INT
    DEF fade4 = NIL:PTR TO INT
    DEF i
    DEF step
    DEF v
    DEF r, g, b

    ncolors := Min(vport.colormap.count, max_colors)
    IF KickVersion(39)
        ncolors32 := (ncolors * 3) + 2
        NEW color32[ncolors32]
        NEW fade32[ncolors32]
        GetRGB32(vport.colormap, 0, ncolors, color32 + 4)
        color32[0] := Shl(ncolors, 16)
        fade32[0] := color32[0]
        FOR step := steps - 1 TO 0 STEP -1
            FOR i := 0 TO (ncolors * 3) - 1
                v := Shr(color32[i + 1], 24) AND $ff
                fade32[i + 1] := Mul(((v * step) / steps), $01010101)
            ENDFOR
            WaitTOF()
            LoadRGB32(vport, fade32)
        ENDFOR
    ELSE
        NEW color4[ncolors]
        NEW fade4[ncolors]
        FOR i := 0 TO ncolors - 1
            color4[i] := GetRGB4(vport.colormap, i)
        ENDFOR
        FOR step := steps - 1 TO 0 STEP -1
            FOR i := 0 TO ncolors - 1
                r := ((Shr(color4[i], 8) AND $0f) * step) / steps
                g := ((Shr(color4[i], 4) AND $0f) * step) / steps
                b := ((color4[i] AND $0f) * step) / steps
                fade4[i] := Shl(r, 8) OR Shl(g, 4) OR b
            ENDFOR
            WaitTOF()
            LoadRGB4(vport, fade4, ncolors)
        ENDFOR
    ENDIF

    IF color32 THEN END color32[ncolors32]
    IF fade32 THEN END fade32[ncolors32]
    IF color4 THEN END color4[ncolors]
    IF fade4 THEN END fade4[ncolors]
ENDPROC

-> Fade in new palette.
EXPORT PROC fade_in_vport(colors:PTR TO rgbcolor, vport:PTR TO viewport, max_colors:LONG, steps:LONG)
    DEF ncolors
    DEF ncolors32
    DEF fade32 = NIL:PTR TO LONG
    DEF fade4 = NIL:PTR TO INT
    DEF i
    DEF step
    DEF r, g, b

    ncolors := Min(vport.colormap.count, max_colors)
    IF KickVersion(39)
        ncolors32 := (ncolors * 3) + 2
        NEW fade32[ncolors32]
        fade32[0] := Shl(ncolors, 16)
        FOR step := 1 TO steps
            FOR i := 0 TO ncolors - 1
                fade32[(i * 3) + 1] := Mul((colors[i].r * step) / steps, $01010101)
                fade32[(i * 3) + 2] := Mul((colors[i].g * step) / steps, $01010101)
                fade32[(i * 3) + 3] := Mul((colors[i].b * step) / steps, $01010101)
            ENDFOR
            WaitTOF()
            LoadRGB32(vport, fade32)
        ENDFOR
    ELSE
        NEW fade4[ncolors]
        FOR step := 1 TO steps
            FOR i := 0 TO ncolors - 1
                r := Shr((colors[i].r * step) / steps, 4)
                g := Shr((colors[i].g * step) / steps, 4)
                b := Shr((colors[i].b * step) / steps, 4)
                fade4[i] := Shl(r, 8) OR Shl(g, 4) OR b
            ENDFOR
            WaitTOF()
            LoadRGB4(vport, fade4, ncolors)
        ENDFOR
    ENDIF

    IF fade32 THEN END fade32[ncolors32]
    IF fade4 THEN END fade4[ncolors]
ENDPROC

