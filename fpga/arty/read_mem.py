#!/usr/bin/env python3
import sys
import argparse
sys.path.append('run')
from bus_interface import *

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', dest='device', default='/dev/ttyUSB2', help='Serial Device')
    parser.add_argument('-a', dest='address', required=True, help='Address to read from (hex)')
    parser.add_argument('-l', dest='length', default='16', help='Number of bytes to read')
    args = parser.parse_args()

    bus_if = BusInterface('uart', args.device, 1000000)
    
    addr = int(args.address, 0)
    length = int(args.length, 0)
    
    print(f"Reading {length} bytes from 0x{addr:08x}:")
    try:
        data = bus_if.read(addr, length)
        
        # Print hex dump
        for i in range(0, len(data), 16):
            line_addr = addr + i
            line_data = data[i:i+16]
            hex_str = ' '.join(f'{b:02x}' for b in line_data)
            ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in line_data)
            print(f"{line_addr:08x}: {hex_str:<48} {ascii_str}")
            
    except Exception as e:
        print(f"Error reading memory: {e}")

if __name__ == "__main__":
    main()