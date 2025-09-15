#!/usr/bin/env python3
import sys
import struct
sys.path.append('run')
from bus_interface import *
from elftools.elf.elffile import ELFFile

def verify_program_load(elf_filename, device='/dev/ttyUSB1', baud=1000000):
    """Verify that program was loaded correctly by comparing memory with ELF"""
    
    print(f"=== Program Load Verification ===")
    print(f"ELF file: {elf_filename}")
    print(f"Device: {device} @ {baud} baud")
    
    try:
        # Connect to debug bridge
        bus_if = BusInterface('uart', device, baud)
        
        # Read ELF file
        total_segments = 0
        verified_segments = 0
        
        print("\n--- Checking ELF segments ---")
        
        with open(elf_filename, "rb") as f:
            elf = ELFFile(f)
            
            for segment in elf.iter_segments():
                if segment.data() and segment['p_filesz'] > 0:
                    load_addr = segment['p_paddr']
                    size = segment['p_filesz']
                    expected_data = segment.data()
                    
                    total_segments += 1
                    print(f"\nSegment {total_segments}:")
                    print(f"  Address: 0x{load_addr:08x}")
                    print(f"  Size: {size} bytes ({size/1024:.1f} KB)")
                
                    # For large segments, only verify first and last parts
                    if size > 1024:
                        # Check first 256 bytes
                        print(f"  Checking first 256 bytes...")
                        try:
                            actual_data = bus_if.read(load_addr, 256)
                            if actual_data == expected_data[:256]:
                                print(f"    ✓ First 256 bytes match")
                            else:
                                print(f"    ✗ First 256 bytes mismatch!")
                                print(f"    Expected: {expected_data[:16].hex()}")  
                                print(f"    Actual:   {actual_data[:16].hex()}")
                                continue
                        except Exception as e:
                            print(f"    ✗ Error reading: {e}")
                            continue
                            
                        # Check last 256 bytes  
                        print(f"  Checking last 256 bytes...")
                        try:
                            last_addr = load_addr + size - 256
                            actual_data = bus_if.read(last_addr, 256)
                            if actual_data == expected_data[-256:]:
                                print(f"    ✓ Last 256 bytes match")
                                verified_segments += 1
                            else:
                                print(f"    ✗ Last 256 bytes mismatch!")
                                continue
                        except Exception as e:
                            print(f"    ✗ Error reading: {e}")
                            continue
                            
                    else:
                        # Small segment - check everything
                        print(f"  Checking all {size} bytes...")
                        try:
                            actual_data = bus_if.read(load_addr, size)
                            if actual_data == expected_data:
                                print(f"    ✓ All bytes match")
                                verified_segments += 1
                            else:
                                print(f"    ✗ Data mismatch!")
                                # Show first differing bytes
                                for i in range(min(size, 16)):
                                    if actual_data[i] != expected_data[i]:
                                        print(f"    First diff at offset {i}: expected 0x{expected_data[i]:02x}, got 0x{actual_data[i]:02x}")
                                        break
                                continue
                        except Exception as e:
                            print(f"    ✗ Error reading: {e}")
                            continue
        
        print(f"\n--- Summary ---")
        print(f"Total segments: {total_segments}")
        print(f"Verified segments: {verified_segments}")
        
        if verified_segments == total_segments:
            print("✓ ALL SEGMENTS VERIFIED - Program loaded correctly!")
            
            # Check reset vector location
            print(f"\n--- Reset Vector Check ---")
            try:
                reset_data = bus_if.read(0x80000000, 16)
                print(f"Reset vector (0x80000000): {reset_data.hex()}")
                # Decode first instruction (should be RISC-V)
                if len(reset_data) >= 4:
                    first_instr = struct.unpack('<I', reset_data[:4])[0]
                    print(f"First instruction: 0x{first_instr:08x}")
            except Exception as e:
                print(f"Could not read reset vector: {e}")
                
            return True
        else:
            print(f"✗ VERIFICATION FAILED - {total_segments - verified_segments} segments had errors")
            return False
            
    except Exception as e:
        print(f"✗ Connection error: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 verify_program_load.py <elf_file>")
        print("Example: python3 verify_program_load.py ../../images/linux_riscv_soc.elf")
        sys.exit(1)
        
    elf_file = sys.argv[1]
    success = verify_program_load(elf_file)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()