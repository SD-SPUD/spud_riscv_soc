# RISC-V SoC Testbench Guide

This document explains how the SystemC/Verilator testbench works and how to add new ports when extending the SoC.

## Overview

The testbench uses SystemC with Verilator to simulate the RISC-V SoC. It consists of several key components:

- **Verilated RTL**: Generated Verilog modules converted to SystemC
- **SystemC Wrapper**: C++ wrapper that connects Verilated modules to testbench
- **Memory Model**: AXI4 memory simulation
- **Test Framework**: RISC-V ISA simulator integration

## Architecture

```
testbench.h/cpp     <- Main testbench class
    |
    v
riscv_soc.h/cpp     <- SystemC wrapper for RTL
    |
    v
Vriscv_soc.h/cpp    <- Verilated RTL (auto-generated)
```

## Adding New Ports (Example: LED Controller)

When you add new ports to the Verilog SoC, you need to update multiple files. Here's the complete process using the LED controller as an example:

### 1. Verilog Changes (Already Done)

First, the Verilog module needs the new port:

```verilog
// In riscv_soc.v
module riscv_soc
(
    // ... existing ports ...
    ,output [1:0]    led_o        // New LED output port
);
```

### 2. Update SystemC Wrapper Header (riscv_soc.h)

Add the port declaration to the public interface:

```cpp
class riscv_soc: public sc_module
{
public:
    // ... existing ports ...
    sc_out <sc_uint<2> > led_o;        // Add LED output port
```

Add internal signal for the port:

```cpp
private:
    // ... existing signals ...
    sc_signal <sc_uint<2> > m_led_out; // Internal LED signal
```

Add to trace function:

```cpp
virtual void add_trace(sc_trace_file *vcd, std::string prefix)
{
    // ... existing traces ...
    TRACE_SIGNAL(led_o);                // Add LED to traces
}
```

### 3. Update SystemC Wrapper Implementation (riscv_soc.cpp)

Connect the Verilated module port in constructor:

```cpp
riscv_soc::riscv_soc(sc_module_name name): sc_module(name)
{
    // ... existing connections ...
    m_rtl->led_o(m_led_out);            // Connect to Verilated port
```

Add to sensitivity list:

```cpp
SC_METHOD(async_outputs);
// ... existing sensitivities ...
sensitive << m_led_out;                 // Add LED to sensitivity list
```

Add output assignment in async_outputs method:

```cpp
void riscv_soc::async_outputs(void)
{
    // ... existing assignments ...
    led_o.write(m_led_out.read());      // Connect internal to external
}
```

### 4. Update Main Testbench (testbench.h)

Add signal declaration:

```cpp
class testbench: public testbench_vbase
{
    // ... existing signals ...
    sc_signal <sc_uint<2> >      led_out;    // LED testbench signal
```

Connect in constructor:

```cpp
testbench(sc_module_name name): testbench_vbase(name)
{
    // ... existing connections ...
    m_dut->led_o(led_out);               // Connect DUT LED port
```

## Build Process

The build happens in stages:

1. **Generate Verilated Code**: `make -f makefile.generate_verilated`
   - Runs Verilator on Verilog sources
   - Creates `Vriscv_soc.h/cpp` and related files

2. **Build Verilated Library**: `make -f makefile.build_verilated`
   - Compiles Verilated C++ code
   - Creates `libsyscverilated.a`

3. **Build SystemC Testbench**: `make -f makefile.build_sysc_tb`
   - Compiles testbench C++ code
   - Links with SystemC and Verilated libraries

## Common Port Types

### Output Ports (SoC → Testbench)

```cpp
// Header
sc_out <TYPE> port_name;
sc_signal <TYPE> m_internal_signal;

// Implementation
m_rtl->port_name(m_internal_signal);
sensitive << m_internal_signal;
port_name.write(m_internal_signal.read());
```

### Input Ports (Testbench → SoC)

```cpp
// Header
sc_in <TYPE> port_name;
sc_signal <TYPE> m_internal_signal;

// Implementation
m_rtl->port_name(m_internal_signal);
m_internal_signal.write(port_name.read());
```

### Common SystemC Types

- `bool` - Single bit
- `sc_uint<N>` - N-bit unsigned integer
- `sc_int<N>` - N-bit signed integer
- `sc_bv<N>` - N-bit bit vector

## Debugging

### Port Binding Errors

Error: `port not bound: port 'tb.DUT.Vriscv_soc.port_name'`

**Solution**: Add the missing port to all three files (riscv_soc.h, riscv_soc.cpp, testbench.h)

### Compilation Errors

Error: `'class riscv_soc' has no member named 'port_name'`

**Solution**: Add port declaration to riscv_soc.h header file

### Missing Signals

Error: Signal not found in traces or simulation doesn't reflect changes

**Solution**: Ensure port is added to:
1. Sensitivity list in riscv_soc.cpp
2. async_outputs method in riscv_soc.cpp
3. Trace function in riscv_soc.h

## Testing New Ports

1. **Build**: `make clean && make build`
2. **Run**: `./build/test.x -f program.elf`
3. **Check VCD**: Open waveform file to verify signals
4. **Monitor**: Add debug prints if needed

## File Checklist for New Ports

When adding a new port, update these files:

- [ ] `riscv_soc.h` - Port declaration, internal signal, trace
- [ ] `riscv_soc.cpp` - Connection, sensitivity, assignment
- [ ] `testbench.h` - Testbench signal, connection
- [ ] Rebuild with `make clean && make build`
- [ ] Test with sample program

## Example: Adding UART Status Port

```cpp
// 1. riscv_soc.h
sc_out <bool> uart_busy_o;
sc_signal <bool> m_uart_busy_out;
TRACE_SIGNAL(uart_busy_o);

// 2. riscv_soc.cpp
m_rtl->uart_busy_o(m_uart_busy_out);
sensitive << m_uart_busy_out;
uart_busy_o.write(m_uart_busy_out.read());

// 3. testbench.h
sc_signal <bool> uart_busy_out;
m_dut->uart_busy_o(uart_busy_out);
```

This systematic approach ensures all new ports are properly connected through the entire testbench hierarchy.

## Adding Other Modules to the Testbench

You can add additional modules to the testbench in several ways depending on your needs:

### 1. Separate Verilated Modules

For standalone Verilog modules that you want to test independently:

**Example: Adding a standalone SPI flash controller**

```cpp
// In testbench.h
#include "Vspi_flash_controller.h"  // Verilated header

class testbench: public testbench_vbase
{
private:
    Vspi_flash_controller *m_spi_flash;  // Verilated module instance

    // Signals for the module
    sc_signal <bool> spi_flash_clk;
    sc_signal <bool> spi_flash_cs;
    sc_signal <bool> spi_flash_mosi;
    sc_signal <bool> spi_flash_miso;

public:
    // Constructor
    testbench(sc_module_name name): testbench_vbase(name)
    {
        // ... existing DUT setup ...

        // Create and connect SPI flash module
        m_spi_flash = new Vspi_flash_controller("SPI_FLASH");
        m_spi_flash->clk_i(clk);
        m_spi_flash->rst_i(rst);
        m_spi_flash->cs_i(spi_flash_cs);
        m_spi_flash->mosi_i(spi_flash_mosi);
        m_spi_flash->miso_o(spi_flash_miso);

        // Connect to main SoC SPI signals
        spi_flash_cs.write(m_dut->spi_cs_out.read());
        spi_flash_mosi.write(m_dut->spi_mosi_out.read());
        // Connect flash output back to SoC input
        // m_dut->spi_miso_in(spi_flash_miso);
    }
};
```

**Makefile changes for separate modules:**

```makefile
# In makefile.generate_verilated, add your module
verilator --sc ../path/to/spi_flash_controller.v --Mdir verilated_spi -I../soc
```

### 2. SystemC-Only Test Modules

For pure SystemC modules (stimulus generators, monitors, etc.):

**Example: Adding a UART monitor**

```cpp
// Create uart_monitor.h
class uart_monitor: public sc_module
{
public:
    sc_in<bool> uart_tx;
    sc_in<bool> clk;

    SC_HAS_PROCESS(uart_monitor);
    uart_monitor(sc_module_name name): sc_module(name)
    {
        SC_METHOD(monitor_uart);
        sensitive << uart_tx.pos() << uart_tx.neg();
        dont_initialize();
    }

private:
    void monitor_uart()
    {
        // Decode UART data and print to console
        if (uart_tx.read() == 0) {
            // Start bit detected
            cout << "UART: Start bit detected at " << sc_time_stamp() << endl;
        }
    }
};

// In testbench.h
#include "uart_monitor.h"

class testbench: public testbench_vbase
{
private:
    uart_monitor *m_uart_mon;

public:
    testbench(sc_module_name name): testbench_vbase(name)
    {
        // ... existing setup ...

        // Add UART monitor
        m_uart_mon = new uart_monitor("UART_MON");
        m_uart_mon->uart_tx(uart_rxd_out);  // Connect to SoC UART output
        m_uart_mon->clk(clk);
    }
};
```

### 3. External Device Models

For modeling external devices that connect to your SoC:

**Example: Adding an I2C EEPROM model**

```cpp
// Create i2c_eeprom.h
class i2c_eeprom: public sc_module
{
public:
    sc_in<bool> scl;
    sc_inout<bool> sda;  // Bidirectional I2C data

    SC_HAS_PROCESS(i2c_eeprom);
    i2c_eeprom(sc_module_name name): sc_module(name)
    {
        SC_THREAD(eeprom_process);
    }

private:
    uint8_t memory[1024];  // 1KB EEPROM

    void eeprom_process()
    {
        while (true) {
            wait(scl.posedge_event());
            // I2C protocol handling
            // Read/write to memory array
        }
    }
};

// In testbench.h
class testbench: public testbench_vbase
{
private:
    i2c_eeprom *m_eeprom;
    sc_signal<bool> i2c_scl;
    sc_signal<bool> i2c_sda;

public:
    testbench(sc_module_name name): testbench_vbase(name)
    {
        // ... existing setup ...

        // Add I2C EEPROM
        m_eeprom = new i2c_eeprom("I2C_EEPROM");
        m_eeprom->scl(i2c_scl);
        m_eeprom->sda(i2c_sda);

        // Connect to SoC I2C pins (if available)
        // i2c_scl.write(m_dut->i2c_scl_out.read());
        // i2c_sda <-> bidirectional connection
    }
};
```

### 4. Multi-Module System Integration

For complex systems with multiple interconnected modules:

**Example: CPU + GPU + Memory controller system**

```cpp
// In testbench.h
class testbench: public testbench_vbase
{
private:
    // Multiple DUTs
    riscv_soc    *m_cpu_soc;      // Main CPU SoC
    Vgpu_core    *m_gpu;          // GPU core
    Vmem_ctrl    *m_mem_ctrl;     // Memory controller

    // Interconnect signals
    sc_signal<axi4_master> cpu_to_mem;
    sc_signal<axi4_master> gpu_to_mem;
    sc_signal<axi4_slave>  mem_response;

public:
    testbench(sc_module_name name): testbench_vbase(name)
    {
        // Create all modules
        m_cpu_soc = new riscv_soc("CPU_SOC");
        m_gpu = new Vgpu_core("GPU");
        m_mem_ctrl = new Vmem_ctrl("MEM_CTRL");

        // Connect CPU
        m_cpu_soc->clk_in(clk);
        m_cpu_soc->rst_in(rst);
        m_cpu_soc->mem_out(cpu_to_mem);

        // Connect GPU
        m_gpu->clk_i(clk);
        m_gpu->rst_i(rst);
        m_gpu->axi_out(gpu_to_mem);

        // Connect memory controller
        m_mem_ctrl->clk_i(clk);
        m_mem_ctrl->rst_i(rst);
        m_mem_ctrl->cpu_axi_in(cpu_to_mem);
        m_mem_ctrl->gpu_axi_in(gpu_to_mem);
        m_mem_ctrl->axi_out(mem_response);

        // Connect responses back
        m_cpu_soc->mem_in(mem_response);
        m_gpu->axi_in(mem_response);
    }
};
```

### 5. Adding Modules to Build System

**For new Verilog modules**, update `makefile.generate_verilated`:

```makefile
# Add your new modules to Verilator command
verilator --sc ../soc/riscv_soc.v ../soc/your_new_module.v \
    --Mdir verilated -I../soc --pins-sc-uint --trace
```

**For SystemC-only modules**, update `makefile.build_sysc_tb`:

```makefile
# Add your new .cpp files to the build
SRC_LIST += your_module.cpp
SRC_LIST += another_module.cpp
```

### 6. Module Communication Patterns

**Direct Signal Connection:**
```cpp
// Direct wire connection
module1_output_signal(module2_input_signal);
```

**Through Intermediate Signals:**
```cpp
// Via intermediate signals for monitoring/debugging
sc_signal<bool> intermediate_sig;
m_module1->output_port(intermediate_sig);
m_module2->input_port(intermediate_sig);
```

**Bus Interfaces:**
```cpp
// AXI4 bus connection
sc_signal<axi4_master> axi_bus;
m_master->axi_out(axi_bus);
m_slave->axi_in(axi_bus);
```

### 7. Module Configuration and Parameters

**Parameterized Modules:**
```cpp
// If your Verilog module has parameters
// Use Verilator command line: --Gparam_name=value
// Or in SystemC wrapper:
class configurable_module: public sc_module
{
public:
    static const int PARAM_VALUE = 64;  // Compile-time parameter

    configurable_module(sc_module_name name, int runtime_param)
        : sc_module(name), m_config(runtime_param)
    {
        // Use m_config for runtime configuration
    }

private:
    int m_config;
};
```

### Common Use Cases

1. **Protocol Analyzers**: Monitor bus transactions, UART data, etc.
2. **Device Models**: EEPROM, flash memory, sensors
3. **Traffic Generators**: Generate test patterns, stress tests
4. **Performance Monitors**: Measure bandwidth, latency
5. **Debug Interfaces**: JTAG, SWD emulation
6. **Clock/Reset Generators**: Custom timing scenarios

This modular approach allows you to build comprehensive system-level testbenches that can verify complex interactions between multiple components.