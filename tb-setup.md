# SystemC/Verilator Testbench Setup Guide

These are some notes on how to get the test benches running in 2025. This scripts in this repo have compatibility errors with Verilator.

## Problem Summary

The original build failed due to incompatibility between the codebase (designed for ~2016 era tools) and modern Verilator 5.x:

- **API Incompatibilities**: `Verilated::stackCheck()` doesn't exist in 5.x
- **Method Signature Changes**: `VerilatedScope::configure()` parameter count changed
- **Trace API Changes**: `VerilatedTraceBaseC` vs `VerilatedScTraceBase` mismatch
- **Environment Issues**: `NAME=fanktop` environment variable caused wrong module lookup

## Solution: Downgrade to Verilator 3.890 (2016)

### Step 1: Remove Modern Verilator
```bash
# Note: We couldn't use sudo in this environment, but normally you'd run:
# sudo apt remove verilator
```

### Step 2: Build Verilator 3.890 from Source

1. **Download and extract Verilator 3.890:**
```bash
cd /tmp
wget https://github.com/verilator/verilator/archive/v3.890.tar.gz
tar -xzf v3.890.tar.gz
cd verilator-3.890
```

2. **Generate configure script:**
```bash
autoconf  # Generates configure script from configure.ac
```

3. **Configure for local installation:**
```bash
./configure --prefix=$HOME/verilator-3.890
```

4. **Build (fix missing header issue):**
```bash
make -j4
# If build fails with "verilog.h: No such file or directory", fix with:
cd src/obj_dbg && ln -sf V3ParseBison.h verilog.h
cd ../obj_opt && ln -sf V3ParseBison.h verilog.h
cd ../..
make -j4  # Continue build
```

5. **Install:**
```bash
make install
```

6. **Update PATH:**
```bash
export PATH=$HOME/verilator-3.890/bin:$PATH
# Verify: verilator --version should show "Verilator 3.890 2016-11-25"
```

### Step 3: Update Build Configuration

1. **Update include paths in makefiles:**

Edit `tb/makefile`:
```makefile
VERILATOR_SRC ?= /home/fank/verilator-3.890/share/verilator/include
```

Edit `tb/makefile.build_verilated`:
```makefile
VERILATOR_SRC ?= /home/fank/verilator-3.890/share/verilator/include
```

2. **Re-enable tracing support:**

Edit `tb/makefile.build_verilated`:
```makefile
# Re-enabled with Verilator 3.890 - tracing should work properly now
CFLAGS += -DVM_TRACE=1 -DVL_USER_FINISH=1

# Re-enabled with Verilator 3.890
SRC_LIST += $(VERILATOR_SRC)/verilated_vcd_c.cpp
SRC_LIST += $(VERILATOR_SRC)/verilated_vcd_sc.cpp
```

Edit `tb/makefile.build_sysc_tb`:
```makefile
# Re-enabled with Verilator 3.890
CFLAGS += -DVM_TRACE=1
```

3. **Fix testbench tracing compatibility:**

Edit `tb/testbench_vbase.h` to make tracing conditional:
```cpp
#include <systemc.h>
#include "verilated.h"
#ifdef VM_TRACE
#include "verilated_vcd_sc.h"
#endif

#ifdef VM_TRACE
#define verilator_trace_enable(vcd_filename, dut) \
        if (waves_enabled()) \
        { \
            Verilated::traceEverOn(true); \
            VerilatedVcdSc *v_vcd = new VerilatedVcdSc; \
            dut->trace_enable (v_vcd); \
            v_vcd->open (vcd_filename); \
            this->m_verilate_vcd = v_vcd; \
        }
#else
#define verilator_trace_enable(vcd_filename, dut) // No tracing
#endif

// Make member variable conditional
protected:
#ifdef VM_TRACE
    VerilatedVcdC   *m_verilate_vcd;
#endif

// Make abort function conditional
virtual void abort(void)
{
    cout << "TB: Aborted at " << sc_time_stamp() << endl;
#ifdef VM_TRACE
    if (m_verilate_vcd)
    {
        m_verilate_vcd->flush();
        m_verilate_vcd->close();
        m_verilate_vcd = NULL;
    }
#endif
}
```

### Step 4: Build and Test

1. **Clean and build:**
```bash
export PATH=$HOME/verilator-3.890/bin:$PATH
unset NAME  # Important: Clear any NAME environment variable
make clean
env VERILATE_PARAMS="--trace -Wno-fatal" make
```

2. **Run the example:**
```bash
make run
```

## Expected Output

Successful run should show:
```
Info: (I702) default timescale unit used for tracing: 1 ns (sysc_wave.vcd)
Memory: 0x2000 - 0x3cd3 (Size=7KB) [.text]
Memory: 0x3cd4 - 0x3ce7 (Size=0KB) [.data]  
Memory: 0x3ce8 - 0x4d07 (Size=4KB) [.bss]
Starting from 0x00002000

Test:
1. Initialised data
2. Multiply
3. Divide
4. Shift left
5. Shift right
6. Shift right arithmetic
7. Signed comparision
8. Word access
9. Byte access
10. Comparision
TB: Aborted at 110 us
```

## Key Dependencies

- **SystemC 2.3.3**: Pre-installed at `/home/fank/systemc-2.3.3`
- **Verilator 3.890**: Built from source
- **GCC**: Standard system compiler
- **Make**: Standard build tool
- **autoconf**: For generating Verilator configure script
- **libelf**: For ELF file parsing
- **bison/flex**: For Verilator parser generation

## Troubleshooting

1. **`NAME=fanktop` error**: Run `unset NAME` before building
2. **Missing verilog.h**: Create symlinks in obj directories as shown above
3. **Trace compilation errors**: Either disable tracing or use conditional compilation as shown
4. **API errors**: Ensure using Verilator 3.890, not 5.x

## Alternative Approach

If building Verilator 3.890 is problematic, you could try:
1. Using Docker with Ubuntu 16.04 and period-appropriate tools
2. Finding pre-built Verilator 3.890 packages
3. Updating the testbench code to work with modern Verilator APIs

## Files Modified

- `tb/makefile` - Updated VERILATOR_SRC path
- `tb/makefile.build_verilated` - Updated paths and re-enabled tracing  
- `tb/makefile.build_sysc_tb` - Re-enabled VM_TRACE
- `tb/testbench_vbase.h` - Added conditional tracing support

## Success Metrics

- ✅ All 10 basic tests pass
- ✅ ELF loading works correctly
- ✅ RISC-V CPU simulation functional
- ✅ SystemC integration working
- ✅ Memory mapping correct
- ✅ No API compatibility errors
