#!/usr/bin/env python3
import sys
import argparse

from bus_interface import *

##################################################################
# Main
##################################################################
def main(argv):
    
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', dest='type',   default='uart',                  help='Device type (uart|ftdi)')
    parser.add_argument('-d', dest='device', default='/dev/ttyUSB1',          help='Serial Device')
    parser.add_argument('-b', dest='baud',   default=1000000,       type=int, help='Baud rate')
    parser.add_argument('-a', dest='address',required=True,                   help='Address to read from')
    args = parser.parse_args()

    bus_if = BusInterface(args.type, args.device, args.baud)

    addr = int(args.address, 0)
    
    try:
        value = bus_if.read32(addr)
        print(f"0x{addr:08x}: 0x{value:08x}")
    except Exception as e:
        print(f"Error reading from 0x{addr:08x}: {e}")

if __name__ == "__main__":
    main(sys.argv[1:])