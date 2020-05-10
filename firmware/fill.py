#!/usr/bin/env python3
#

"""Fill unused areas of 32k ROM image with a recognizable pattern.

Each 16 byte chunk is filled with:
  Address (2 bytes)
  0x00
  0x80
  0x51
  0x00
  "8051dumper"
"""

import argparse
import intelhex


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='fill.py',
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument('infile', metavar='INFILE')
    parser.add_argument('outfile', metavar='OUTFILE')

    args = parser.parse_args()

    fw_image = intelhex.IntelHex(args.infile)

    fill = list(b'\x00\x00\x00\x80\x51\x008051dumper' * int(32768/16))
    for n in range(0, len(fill), 16):
        fill[n]   = n>>8
        fill[n+1] = n & 0xFF

    filled_image = intelhex.IntelHex()
    filled_image.frombytes(bytes(fill))
    filled_image.merge(fw_image, overlap='replace')

    filled_image.write_hex_file(args.outfile)