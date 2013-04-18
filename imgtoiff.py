#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import optparse
try:
    from PIL import Image
except ImportError:
    print >>sys.stderr, "Pillow is required, install with sudo pip install pillow"
    sys.exit(1)
import array
import math
import struct
import cStringIO as StringIO


def packbits(data):
    # https://github.com/kmike/packbits
    # 
    # Copyright (c) 2013 Mikhail Korobov
    # 
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    # 
    # The above copyright notice and this permission notice shall be included in
    # all copies or substantial portions of the Software.
    # 
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    # THE SOFTWARE.
    
    if len(data) == 0:
        return data

    if len(data) == 1:
        return b'\x00' + data

    data = bytearray(data)

    result = bytearray()
    buf = bytearray()
    pos = 0
    repeat_count = 0
    MAX_LENGTH = 127

    # we can safely start with RAW as empty RAW sequences
    # are handled by finish_raw()
    state = 'RAW'

    def finish_raw():
        if len(buf) == 0:
            return
        result.append(len(buf)-1)
        result.extend(buf)
        buf[:] = bytearray()

    def finish_rle():
        result.append(256-(repeat_count - 1))
        result.append(data[pos])

    while pos < len(data)-1:
        current_byte = data[pos]

        if data[pos] == data[pos+1]:
            if state == 'RAW':
                # end of RAW data
                finish_raw()
                state = 'RLE'
                repeat_count = 1
            elif state == 'RLE':
                if repeat_count == MAX_LENGTH:
                    # restart the encoding
                    finish_rle()
                    repeat_count = 0
                # move to next byte
                repeat_count += 1

        else:
            if state == 'RLE':
                repeat_count += 1
                finish_rle()
                state = 'RAW'
                repeat_count = 0
            elif state == 'RAW':
                if len(buf) == MAX_LENGTH:
                    # restart the encoding
                    finish_raw()

                buf.append(current_byte)

        pos += 1

    if state == 'RAW':
        buf.append(data[pos])
        finish_raw()
    else:
        repeat_count += 1
        finish_rle()

    return bytes(result)

def unpackbits(data):
    data = bytearray(data) # <- python 2/3 compatibility fix
    result = bytearray()
    pos = 0
    while pos < len(data):
        header_byte = data[pos]
        if header_byte > 127:
            header_byte -= 256
        pos += 1

        if 0 <= header_byte <= 127:
            result.extend(data[pos:pos+header_byte+1])
            pos += header_byte+1
        elif header_byte == -128:
            pass
        else:
            result.extend([data[pos]] * (1 - header_byte))
            pos += 1

    return bytes(result)

# Converted from lz78.c by Ray/tSCc.
LZ78_BITS =             12
LZ78_HASHING_SHIFT =    LZ78_BITS - 8
LZ78_LALIGN =           32 - LZ78_BITS
LZ78_MAX_VALUE =        (1 << LZ78_BITS) - 1
LZ78_MAX_CODE =         LZ78_MAX_VALUE - 1
if LZ78_BITS == 14:
    LZ78_TABLE_SIZE = 18041
elif LZ78_BITS == 13:
    LZ78_TABLE_SIZE = 9029
elif LZ78_BITS == 12:
    LZ78_TABLE_SIZE = 5021

code_value =       array.array("i", (0 for i in xrange(LZ78_TABLE_SIZE)))
prefix_code =      array.array("i", (0 for i in xrange(LZ78_TABLE_SIZE)))
append_character = array.array("B", (0 for i in xrange(LZ78_TABLE_SIZE)))

output_bit_count = 0
output_bit_buffer = 0

def output_code(outp, code):
    global output_bit_count
    global output_bit_buffer
    
    output_bit_buffer |= code << (LZ78_LALIGN - output_bit_count)
    output_bit_count += LZ78_BITS
    while output_bit_count >= 8:
        outp.write(chr((output_bit_buffer >> 24) & 0xff))
        output_bit_buffer <<= 8
        output_bit_count -= 8

def find_match(hash_prefix, hash_character):
    global code_value
    global prefix_code
    global append_character
    
    index = (hash_character << LZ78_HASHING_SHIFT) ^ hash_prefix
    if index == 0:
        offset = 1
    else:
        offset = LZ78_TABLE_SIZE - index
    while True:
        if code_value[index] == -1:
            return index
        if (prefix_code[index] == hash_prefix) and (append_character[index] == hash_character):
            return index
        index -= offset
        if index < 0:
            index += LZ78_TABLE_SIZE

def lz78pack(data):
    global code_value
    global prefix_code
    global append_character
    global output_bit_count
    global output_bit_buffer
    
    output_bit_count = 0
    output_bit_buffer = 0
    for i in xrange(LZ78_TABLE_SIZE):
        code_value[i] = -1
        prefix_code[i] = 0
        append_character[i] = 0
    
    inp = StringIO.StringIO(data)
    outp = StringIO.StringIO()
    
    outp.write(struct.pack(">L", len(data)))
    
    next_code = 256
    
    string_code = ord(inp.read(1))
    while True:
        c = inp.read(1)
        if c == "":
            break
        character = ord(c)
        index = find_match(string_code, character)
        if code_value[index] != -1:
            string_code = code_value[index]
        else:
            if next_code <= LZ78_MAX_CODE:
                code_value[index] = next_code
                next_code += 1
                prefix_code[index] = string_code
                append_character[index] = character
            output_code(outp, string_code)
            string_code = character
    
    output_code(outp, string_code)
    output_code(outp, LZ78_MAX_VALUE)
    output_code(outp, 0)
    
    return outp.getvalue()

def iff_chunk(id, *args):
    chunk_len = 0
    data = list()
    for d in args:
        if len(d) & 1:
            data.append(d + "\x00")
            chunk_len += len(d) + 1
        else:
            data.append(d)
            chunk_len += len(d)
    return id + struct.pack(">L", chunk_len) + "".join(data)

def zeros(len):
    for i in xrange(len):
        yield 0

def create_header(width, height, palette, mode, pack):
    depth = int(math.ceil(math.log(len(palette), 2)))
    # Create IFF chunks for header.
    bmhd = iff_chunk("BMHD", struct.pack(">HHHHBBBxHBBHH",
        width,  # w:INT
        height, # h:INT
        0,      # x:INT
        0,      # y:INT
        depth,  # nplanes:CHAR
        0,      # masking:CHAR
        pack,   # compression:CHAR
                # pad:CHAR
        0,      # transparentcolor:INT
        60,     # xaspect:CHAR
        60,     # yaspect:CHAR
        width,  # pagewidth:INT
        height, # pageheight:INT
    ))
    
    cmap = iff_chunk("CMAP", "".join(struct.pack("BBB", r, g, b) for (r, g, b) in palette))
    
    if mode is not None:
        camg = iff_chunk("CAMG", struct.pack(">L", mode))
    else:
        camg = ""
    
    return depth, bmhd, cmap, camg

def convert_planar(width, height, depth, pixels):
    # Calculate dimensions.
    plane_width = ((width + 15) / 16) * 16
    bpr = plane_width / 8
    plane_size = bpr * height
    
    # Convert image to planar bitmap.
    planes = tuple(array.array("B", (0 for i in xrange(plane_size))) for j in xrange(depth))
    for y in xrange(height):
        rowoffset = y * bpr
        for x in xrange(width):
            offset = rowoffset + x / 8
            xmod = 7 - (x & 7)
            p = pixels[x, y]
            for plane in xrange(depth):
                planes[plane][offset] |= ((p >> plane) & 1) << xmod
    
    return bpr, planes

def create_ilbm(width, height, pixels, palette, mode, pack):
    # Get header.
    depth, bmhd, cmap, camg = create_header(width, height, palette, mode, pack)
    # Get planar bitmap.
    bpr, planes = convert_planar(width, height, depth, pixels)
    # Create interleaved bitmap.
    rows = list()
    for y in xrange(height):
        for row in (planes[plane][y * bpr:y * bpr + bpr].tostring() for plane in xrange(depth)):
            rows.append(row)
    
    if pack == 0:       # No compression.
        body = iff_chunk("BODY", "".join(r for r in rows))
    elif pack == 1:     # Packbits.
        body = iff_chunk("BODY", "".join(packbits(r) for r in rows))
    
    form = iff_chunk("FORM", "ILBM", bmhd, cmap, camg, body)
    return form

def create_acbm(width, height, pixels, palette, mode, pack):
    # Get header.
    depth, bmhd, cmap, camg = create_header(width, height, palette, mode, pack)
    # Get planar bitmap.
    bpr, planes = convert_planar(width, height, depth, pixels)
    
    if pack == 0:       # No compression.
        abit = iff_chunk("ABIT", "".join(p.tostring() for p in planes))
    elif pack == 1:     # Packbits.
        abit = iff_chunk("ABIT", "".join(packbits(p.tostring()) for p in planes))
    elif pack == 78:    # LZ78 by Ray of tSCc.
        abit = iff_chunk("ABIT", lz78pack("".join(p.tostring() for p in planes)))
    
    form = iff_chunk("FORM", "ACBM", bmhd, cmap, camg, abit)
    return form
    

AGA = 1
OCS = 2

def main(argv):
    p = optparse.OptionParser()
    p.set_usage("""Usage: %prog [options] infile outfile.iff""")
    p.add_option("-v", "--verbose", action="store_true", help="Verbose output.")
    p.add_option("-o", "--ocs", action="store_true", help="OCS (4 bits per channel).")
    p.add_option("-a", "--aga", action="store_true", help="AGA (8 bits per channel).")
    p.add_option("-s", "--scale", nargs=2, type="int", action="store", help="Scale to width.")
    p.add_option("-c", "--colors", type="int", action="store", help="Max number of colors.")
    p.add_option("-d", "--dither", action="store_true", help="Dither when resampling.")
    p.add_option("-m", "--mode", type="int", action="store", help="Amiga display mode ID.")
    p.add_option("-p", "--pack", type="int", action="store", default=None, help="Select compression algorithm.")
    p.add_option("-f", "--format", action="store", default="ILBM", help="ILBM or ACBM.")
    options, argv = p.parse_args(argv)
    if len(argv) != 3:
        print >>sys.stderr, p.get_usage()
        return 1
    
    # Argument parsing.
    
    infile = argv[1]
    outfile = argv[2]
    
    if options.ocs:
        mode = OCS
        max_colors = 32
    else:
        mode = AGA
        max_colors = 256
    
    if options.scale:
        new_size = options.scale
    else:
        new_size = None
    
    if options.colors:
        if options.colors < 2 or options.colors > max_colors:
            print >>sys.stderr, "Colors should be between 2 and %d" % max_colors
            return 1
        max_colors = options.colors
    
    if options.dither:
        dither = Image.FLOYDSTEINBERG
    else:
        dither = Image.NONE
    
    if options.pack is None:
        if options.format.upper() == "ILBM":
            pack = 1
        else:
            pack = 0
    else:
        pack = options.pack
    
    # Image conversion.
    
    im = Image.open(infile)
    #print im.format, im.size, im.mode
    if new_size is None:
        new_size = im.size
    if (new_size != im.size) or (im.format not in ("P", "L")):
        # Convert to RGB.
        rgb = im.convert("RGB")
        # Resize if needed.
        if new_size != im.size:
            rgb = rgb.resize(new_size, Image.ANTIALIAS)
        if mode == OCS:
            pixels = rgb.load()
            for y in xrange(rgb.size[1]):
                for x in xrange(rgb.size[0]):
                    r, g, b = pixels[x, y]
                    r = (r & 0xf0) | (r >> 4)
                    g = (g & 0xf0) | (g >> 4)
                    b = (b & 0xf0) | (b >> 4)
                    pixels[x, y] = (r, g, b)
        # Convert back to palette mode.
        new_image = rgb.convert("P",
                                dither=dither,
                                palette=Image.ADAPTIVE,
                                colors=max_colors)
    elif len(im.getcolors()) > max_colors:
        new_image = im.convert("P",
                               dither=dither,
                               palette=Image.ADAPTIVE,
                               colors=max_colors)
    else:
        new_image = im.copy()
    
    palette = list()
    p = new_image.im.getpalette("RGB")
    for i in xrange(min(max_colors, len(new_image.getcolors()))):
        r = ord(p[i * 3])
        g = ord(p[i * 3 + 1])
        b = ord(p[i * 3 + 2])
        if mode == OCS:
            palette.append(((r & 0xf0) | (r >> 4),
                            (g & 0xf0) | (g >> 4),
                            (b & 0xf0) | (b >> 4)))
        else:
            palette.append((r, g, b))
    
    pixels = new_image.load()
    width, height = new_image.size
    with open(outfile, "wb") as f:
        if options.format.upper() == "ILBM":
            f.write(create_ilbm(width, height, pixels, palette, options.mode, pack))
        elif options.format.upper() == "ACBM":
            f.write(create_acbm(width, height, pixels, palette, options.mode, pack))
        else:
            print >>sys.stderr, "Unsupported format"
            return 1
    
    return 0
    

if __name__ == '__main__':
    sys.exit(main(sys.argv))
    
