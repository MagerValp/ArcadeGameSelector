#!/usr/bin/python


import sys
import optparse
try:
    from PIL import Image
except ImportError:
    print >>sys.stderr, "Pillow is required"
    raise
import array
import math
import struct


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

def create_ilbm(width, height, pixels, palette, mode):
    # Calculate dimensions.
    depth = int(math.ceil(math.log(len(palette), 2)))
    plane_width = ((width + 15) / 16) * 16
    bpr = plane_width / 8
    plane_size = bpr * height
    # Convert image to planar bitmap.
    planes = tuple(array.array("B", [0 for i in xrange(plane_size)]) for j in xrange(depth))
    for y in xrange(height):
        rowoffset = y * bpr
        for x in xrange(width):
            offset = rowoffset + x / 8
            xmod = 7 - (x & 7)
            p = pixels[x, y]
            for plane in xrange(depth):
                planes[plane][offset] |= ((p >> plane) & 1) << xmod
    # Create interleaved bitmap.
    rows = list()
    for y in xrange(height):
        for row in (planes[plane][y * bpr:y * bpr + bpr].tostring() for plane in xrange(depth)):
            rows.append(row)
    # Create IFF chunks.
    bmhd = iff_chunk("BMHD", struct.pack(">HHHHBBBxHBBHH",
        width,  # w:INT
        height, # h:INT
        0,      # x:INT
        0,      # y:INT
        depth,  # nplanes:CHAR
        0,      # masking:CHAR
        1,      # compression:CHAR
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
    body = iff_chunk("BODY", "".join(packbits(r) for r in rows))
    form = iff_chunk("FORM", "ILBM", bmhd, cmap, camg, body)
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
        f.write(create_ilbm(width, height, pixels, palette, options.mode))
    
    return 0
    

if __name__ == '__main__':
    sys.exit(main(sys.argv))
    
