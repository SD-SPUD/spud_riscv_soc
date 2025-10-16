#!/usr/bin/env python3
import sys
import time
sys.path.append('run')
from bus_interface import *

def test_cpu_reset_control(device='/dev/ttyUSB1', baud=1000000):
    """Test CPU reset control via debug bridge"""
    
    print(f"Testing debug bridge on {device} at {baud} baud...")
    
    try:
        bus_if = BusInterface('uart', device, baud)
        
        # Test 1: Read status register (should return 0xcafeXXXX)
        print("1. Reading debug bridge status register...")
        status = bus_if.read32(0xF0000004)
        print(f"   Status register: 0x{status:08x}")
        
        if (status & 0xFFFF0000) == 0xcafe0000:
            print("   ✓ Debug bridge responding correctly!")
        else:
            print("   ✗ Unexpected status - debug bridge may not be working")
            return False
            
        # Test 2: Read GPIO register (CPU reset control)
        print("2. Reading GPIO register (reset control)...")
        gpio_val = bus_if.read32(0xF0000000)
        print(f"   GPIO register: 0x{gpio_val:08x}")
        print(f"   CPU Reset bit (bit 0): {'RELEASED' if (gpio_val & 1) else 'HELD IN RESET'}")
        
        # Test 3: Release CPU from reset (set bit 0)
        print("3. Releasing CPU from reset...")
        bus_if.write32(0xF0000000, 0x00000001)
        print("   ✓ CPU reset released! (LD2 should turn OFF)")
        
        # Verify the change
        time.sleep(0.1)
        gpio_val = bus_if.read32(0xF0000000)
        print(f"   GPIO register now: 0x{gpio_val:08x}")
        print(f"   CPU Reset bit: {'RELEASED' if (gpio_val & 1) else 'STILL HELD'}")
        
        # Test 4: Put CPU back in reset (clear bit 0)  
        print("4. Putting CPU back in reset...")
        bus_if.write32(0xF0000000, 0x00000000)
        print("   ✓ CPU back in reset! (LD2 should turn ON)")
        
        # Verify the change
        time.sleep(0.1)
        gpio_val = bus_if.read32(0xF0000000)
        print(f"   GPIO register now: 0x{gpio_val:08x}")
        print(f"   CPU Reset bit: {'RELEASED' if (gpio_val & 1) else 'HELD IN RESET'}")
        
        return True
        
    except Exception as e:
        print(f"   ✗ Error: {e}")
        return False

def main():
    print("=== CPU Reset Control Test ===")
    
    # Try different baud rates
    for baud in [1000000, 115200, 9600]:
        print(f"\nTrying {baud} baud...")
        if test_cpu_reset_control(baud=baud):
            print(f"\n✓ Success with {baud} baud!")
            break
        print(f"Failed with {baud} baud")
    else:
        print("\n✗ All baud rates failed - check FPGA programming and connections")

if __name__ == "__main__":
    main()