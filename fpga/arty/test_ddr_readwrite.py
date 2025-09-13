#!/usr/bin/env python3
import sys
import struct
import time
sys.path.append('run')
from bus_interface import *

def test_ddr_readwrite(device='/dev/ttyUSB1', baud=1000000):
    """Comprehensive DDR3 read/write test to isolate corruption issues"""
    
    print("=== DDR3 Read/Write Test ===")
    
    try:
        bus_if = BusInterface('uart', device, baud)
        
        # Test 1: Basic 32-bit word write/read
        print("\n--- Test 1: Basic 32-bit Word Operations ---")
        test_addr = 0x90000000
        test_values = [
            0x12345678,
            0xDEADBEEF,
            0x00000000,
            0xFFFFFFFF,
            0xAAAA5555,
            0x01234567
        ]
        
        for i, test_val in enumerate(test_values):
            print(f"Test {i+1}: Writing 0x{test_val:08x} to 0x{test_addr:08x}")
            
            # Write
            bus_if.write32(test_addr, test_val)
            time.sleep(0.1)  # Small delay
            
            # Read back
            read_val = bus_if.read32(test_addr)
            
            if read_val == test_val:
                print(f"  ✓ SUCCESS: Read back 0x{read_val:08x}")
            else:
                print(f"  ✗ FAIL: Expected 0x{test_val:08x}, got 0x{read_val:08x}")
                # Analyze the corruption
                print(f"    XOR diff: 0x{test_val ^ read_val:08x}")
                
        # Test 2: Sequential address test
        print(f"\n--- Test 2: Sequential Address Test ---")
        base_addr = 0x90000100
        for offset in range(0, 64, 4):
            addr = base_addr + offset
            expected = 0x10000000 + offset
            
            bus_if.write32(addr, expected)
            
        # Read back all
        all_correct = True
        for offset in range(0, 64, 4):
            addr = base_addr + offset
            expected = 0x10000000 + offset
            actual = bus_if.read32(addr)
            
            if actual != expected:
                print(f"  ✗ Address 0x{addr:08x}: expected 0x{expected:08x}, got 0x{actual:08x}")
                all_correct = False
                
        if all_correct:
            print("  ✓ All sequential addresses correct")
            
        # Test 3: Block write/read test 
        print(f"\n--- Test 3: Block Write/Read Test ---")
        block_addr = 0x90001000
        block_size = 256
        
        # Create test pattern
        test_pattern = bytearray()
        for i in range(block_size):
            test_pattern.append(i & 0xFF)
            
        print(f"Writing {block_size} byte pattern to 0x{block_addr:08x}")
        bus_if.write(block_addr, test_pattern, block_size)
        
        print(f"Reading back {block_size} bytes...")
        read_pattern = bus_if.read(block_addr, block_size)
        
        if read_pattern == test_pattern:
            print("  ✓ Block write/read successful")
        else:
            print("  ✗ Block write/read failed")
            # Find first difference
            for i in range(min(len(test_pattern), len(read_pattern))):
                if test_pattern[i] != read_pattern[i]:
                    print(f"    First difference at offset {i}: expected 0x{test_pattern[i]:02x}, got 0x{read_pattern[i]:02x}")
                    break
            # Show pattern analysis
            print(f"    Expected start: {test_pattern[:16].hex()}")
            print(f"    Actual start:   {read_pattern[:16].hex()}")
            
        # Test 4: Endianness test
        print(f"\n--- Test 4: Endianness Test ---")
        endian_addr = 0x90002000
        endian_test = 0x12345678
        
        # Write as 32-bit word
        bus_if.write32(endian_addr, endian_test)
        
        # Read as bytes
        byte_data = bus_if.read(endian_addr, 4)
        print(f"Wrote 0x12345678 as 32-bit word")
        print(f"Read as bytes: {byte_data.hex()}")
        
        # Expected for little endian: 78 56 34 12
        # Expected for big endian: 12 34 56 78
        if byte_data == bytes([0x78, 0x56, 0x34, 0x12]):
            print("  ✓ Little endian confirmed")
        elif byte_data == bytes([0x12, 0x34, 0x56, 0x78]):
            print("  ✓ Big endian confirmed") 
        else:
            print(f"  ✗ Unexpected byte order: {byte_data.hex()}")
            
        # Test 5: Address boundary test
        print(f"\n--- Test 5: Address Alignment Test ---")
        boundary_base = 0x90003000
        
        # Test unaligned vs aligned access
        for offset in [0, 1, 2, 3]:
            addr = boundary_base + offset
            test_val = 0xABCD0000 + offset
            
            try:
                bus_if.write32(addr, test_val)
                read_val = bus_if.read32(addr)
                
                if read_val == test_val:
                    print(f"  ✓ Offset {offset}: 0x{addr:08x} works correctly")
                else:
                    print(f"  ✗ Offset {offset}: 0x{addr:08x} failed (got 0x{read_val:08x})")
                    
            except Exception as e:
                print(f"  ✗ Offset {offset}: 0x{addr:08x} caused error: {e}")
                
        return True
        
    except Exception as e:
        print(f"✗ Test failed: {e}")
        return False

if __name__ == "__main__":
    test_ddr_readwrite()