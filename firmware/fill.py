#!/usr/bin/env python3
#

"""Fill unused areas of 32k ROM image with a recognizable pattern."""

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

    fill = bytes([0xDE, 0xAD, 0xBE, 0xEF]) * int(32768/4)
    filled_image = intelhex.IntelHex()
    filled_image.frombytes(fill)
    filled_image.merge(fw_image, overlap='replace')

    filled_image.write_hex_file(args.outfile)