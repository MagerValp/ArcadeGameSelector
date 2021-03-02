#!/usr/bin/env python3

import sys
import os

def main():
    sort_lut = []
    sort_order = [' ']

    with open('sorting_table', 'r') as f:
        for l in f.readlines():
            if len(l) > 0 and not l[0].isspace():
                sort_order.append(l[0])

    for i in range(256):
        if chr(i) in sort_order:
            sort_lut.append(sort_order.index(chr(i)))
        else:
            sort_lut.append(0)

    for i in range(16):
        items = []
        for j in range(16):
            items.append('${0:02x}'.format(sort_lut[(i*16)+j]))
        print("    CHAR {}".format(','.join(items)))

if __name__ == "__main__":
    sys.exit(main())
