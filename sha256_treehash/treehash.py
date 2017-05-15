#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# Computation functions taken out of uskudnik's code:
# https://github.com/uskudnik/amazon-glacier-cmd-interface (MIT License)
#
import sys
import os
import hashlib
import argparse


def bytes_to_hex(str):
    return ''.join( [ "%02x" % ord( x ) for x in str] ).strip()

def tree_hash(fo):
    """
    Given a hash of each 1MB chunk (from chunk_hashes) this will hash
    together adjacent hashes until it ends up with one big one. So a
    tree of hashes.
    """
    hashes = []
    hashes.extend(fo)
    while len(hashes) > 1:
        new_hashes = []
        while True:
            if len(hashes) > 1:
                first = hashes.pop(0)
                second = hashes.pop(0)
                new_hashes.append(hashlib.sha256(first + second).digest())
            elif len(hashes) == 1:
                only = hashes.pop(0)
                new_hashes.append(only)
            else:
                break
        hashes.extend(new_hashes)
    return hashes[0]

def get_tree_hash(input_file, output_hash_file):
    try:
        reader = open(input_file, 'rb')
        writer = open(output_hash_file, 'w')
    except IOError as e:
        raise InputException(
            "Could not access the file given: %s." % input_file,
            cause=e,
            code='FileError')
    hashes = [hashlib.sha256(part).digest() for part in iter((lambda:reader.read(1024 * 1024)), '')]
    hashes_hex = bytes_to_hex(tree_hash(hashes))
    writer.write(hashes_hex)
    writer.write('\n')
    writer.close()
    reader.close()
    return hashes_hex

def main():
    parser = argparse.ArgumentParser(description='Boo, Far')
    parser.add_argument('input_file', type=str, nargs='+', help='Compute SHA256 tree hases of given files')
    args = parser.parse_args()
    for filename in args.input_file:
        #print("Process: " + filename)
        th=get_tree_hash(filename, filename + ".sha256treehash")
        print(filename + ': ' + th)

if __name__ == "__main__":
    sys.exit(main())

