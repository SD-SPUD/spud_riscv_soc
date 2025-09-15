# RISC-V SoC Register Architecture Deep Dive

## Overview

This document provides a comprehensive understanding of how register writes flow through the RISC-V SoC, from CPU instruction execution to hardware register updates. Use this as a reference for adding custom peripherals and LED registers.

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Stage-by-Stage Signal Flow](#stage-by-stage-signal-flow)
3. [Key Components Deep Dive](#key-components-deep-dive)
4. [GPIO Example Walkthrough](#gpio-example-walkthrough)
5. [Address Map Reference](#address-map-reference)
6. [Adding Custom Peripherals](#adding-custom-peripherals)
7. [File Reference](#file-reference)

---

## High-Level Architecture

The SoC uses a multi-stage bus switching architecture:

```
CPU Core → AXI4 Bridge → AXI4 Arbiter → AXI4-Lite Tap → Peripherals
```

### Bus Hierarchy
- **AXI4**: Full-featured bus for memory access
- **AXI4-Lite**: Simplified bus for peripheral registers
- **Custom Interface**: Peripheral-specific signals

---

## Stage-by-Stage Signal Flow

### Stage 1: CPU Instruction to Memory Interface

**Location**: `core/core/rv32im/riscv_lsu.v`

```c
// C code example
*(volatile uint32_t*)0x94000008 = 0x00000001;
```

The Load-Store Unit (LSU) converts this to:
```verilog
mem_addr_o    = 32'h94000008  // Target address
mem_data_wr_o = 32'h00000001  // Data to write  
mem_wr_o      = 4'b1111       // Byte enables (all bytes)
mem_rd_o      = 1'b0          // Not a read
```

### Stage 2: Memory Interface to AXI4

**Location**: `soc/riscv_soc.v:248` (riscv_top instantiation)

The core wrapper converts LSU signals to full AXI4 protocol:
```verilog
// Two separate AXI4 buses from CPU
axi_i_*  // Instruction bus (code fetches)
axi_d_*  // Data bus (your GPIO write goes here)

// Your write becomes:
axi_d_awvalid_o = 1'b1           // Address valid
axi_d_awaddr_o  = 32'h94000008   // Address
axi_d_wvalid_o  = 1'b1           // Data valid
axi_d_wdata_o   = 32'h00000001   // Data
axi_d_wstrb_o   = 4'b1111        // Byte strobes
```

### Stage 3: AXI4 Arbitration

**Location**: `soc/soc.v:557` (axi4_arb instantiation)

The arbiter merges 4 possible masters:
```verilog
inport0_* ← External debug/DMA master
inport1_* ← CPU data bus (YOUR GPIO WRITE)  
inport2_* ← CPU instruction bus
inport3_* ← Unused
```

**Arbitration Logic** (`soc/axi4_arb.v:206-215`):
```verilog
wire [3:0] read_req_w;
assign read_req_w[1] = inport1_arvalid_i;  // CPU data requesting

// Round-robin one-hot arbiter decides winner
// Grant[1] = 1 means CPU data bus wins
```

**Output Mux** (`soc/axi4_arb.v:245-278`):
```verilog
case (1'b1)
    read_grant_w[1]: begin  // CPU data wins
        outport_araddr_r = inport1_araddr_i;  // 0x94000008
        outport_arvalid_r = inport1_arvalid_i;
    end
endcase
```

### Stage 4: Address Decode and Bus Switching

**Location**: `soc/axi4_lite_tap.v`

This is the critical address decoder that routes transactions to peripherals.

**Address Decode Logic** (Lines 379-387):
```verilog
always @ * begin
    write_port_r = 3'b0;  // Default = main memory
    
    // Peripheral address decode
    if ((inport_awaddr_i & 32'hff000000) == 32'h90000000) write_port_r = 3'd1; // IRQ
    if ((inport_awaddr_i & 32'hff000000) == 32'h91000000) write_port_r = 3'd2; // Timer  
    if ((inport_awaddr_i & 32'hff000000) == 32'h92000000) write_port_r = 3'd3; // UART
    if ((inport_awaddr_i & 32'hff000000) == 32'h93000000) write_port_r = 3'd4; // SPI
    if ((inport_awaddr_i & 32'hff000000) == 32'h94000000) write_port_r = 3'd5; // GPIO ✓
end
```

For address `0x94000008`: `write_port_r = 5` (GPIO)

**Bus Switching Logic** (Lines 458-463):
```verilog
// Only activate GPIO when targeting peripheral 4 (port 5)
assign outport_peripheral4_awvalid_o = inport_awvalid_i & write_accept_w & (write_port_r == 5);
assign outport_peripheral4_awaddr_o  = inport_awaddr_i;     // 0x94000008
assign outport_peripheral4_wvalid_o  = inport_wvalid_i & write_accept_w & (write_port_r == 5);
assign outport_peripheral4_wdata_o   = inport_wdata_i;      // 0x00000001
assign outport_peripheral4_wstrb_o   = inport_wstrb_i;      // 4'b1111
```

### Stage 5: Peripheral Register Processing

**Location**: `soc/soc.v:798-826` (GPIO instantiation)

```verilog
gpio u_gpio (
    .cfg_awvalid_i(axi_tap_output4_awvalid_w),  // Write address valid
    .cfg_awaddr_i(axi_tap_output4_awaddr_w),    // 0x94000008  
    .cfg_wvalid_i(axi_tap_output4_wvalid_w),    // Write data valid
    .cfg_wdata_i(axi_tap_output4_wdata_w),      // 0x00000001
    .cfg_wstrb_i(axi_tap_output4_wstrb_w),      // 4'b1111
);
```

---

## Key Components Deep Dive

### AXI4 Arbiter Details

**File**: `soc/axi4_arb.v`

**Purpose**: Merge multiple AXI masters into single bus

**Key Features**:
- Round-robin arbitration using one-hot arbiter
- Holds grant until transaction complete (prevents conflicts)
- Separate arbitration for read/write channels

**Grant Hold Logic**:
```verilog
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    read_hold_q <= 1'b0;
else if (outport_arvalid_o && !outport_arready_i)
    read_hold_q <= 1'b1;  // Hold grant during transaction
else if (outport_arready_i)  
    read_hold_q <= 1'b0;  // Release when done
```

### AXI4-Lite Tap Details

**File**: `soc/axi4_lite_tap.v`

**Purpose**: Address decode and route to peripherals

**Address Decode Constants**:
```verilog
`define PERIPH0_ADDR    32'h90000000  // IRQ Controller
`define PERIPH1_ADDR    32'h91000000  // Timer
`define PERIPH2_ADDR    32'h92000000  // UART  
`define PERIPH3_ADDR    32'h93000000  // SPI
`define PERIPH4_ADDR    32'h94000000  // GPIO
`define PERIPH4_MASK    32'hff000000  // 16MB address space per peripheral
```

**Write Accept Logic**:
```verilog
wire write_accept_w = (write_port_q == write_port_r && write_pending_q != 4'hF) || (write_pending_q == 4'h0);
```
Prevents conflicts by ensuring only one transaction active at a time.

### GPIO Peripheral Details

**File**: `soc/gpio.v`

**Write Detection**:
```verilog
wire write_en_w = cfg_awvalid_i & cfg_awready_o;
```

**Register Address Decode** (uses low 8 bits):
```verilog
// From gpio_defs.v
`define GPIO_DIRECTION    8'h0   // 0x94000000
`define GPIO_INPUT        8'h4   // 0x94000004  
`define GPIO_OUTPUT       8'h8   // 0x94000008 ← Your target
`define GPIO_OUTPUT_SET   8'hc   // 0x9400000c
`define GPIO_OUTPUT_CLR   8'h10  // 0x94000010
```

**Register Write Logic**:
```verilog
// Detect write to GPIO_OUTPUT register
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    gpio_output_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `GPIO_OUTPUT))
    gpio_output_wr_q <= 1'b1;  // One-cycle pulse
else
    gpio_output_wr_q <= 1'b0;
```

**Data Register Update**:
```verilog
always @ *
begin
    output_next_r = output_q;  // Default: hold current value
    
    if (gpio_output_set_wr_req_w)
        output_next_r = output_q | gpio_output_set_data_out_w;  // Set bits
    else if (gpio_output_clr_wr_req_w)  
        output_next_r = output_q & ~gpio_output_clr_data_out_w; // Clear bits
    else if (gpio_output_wr_req_w)
        output_next_r = gpio_output_data_out_w;  // Direct write ← Your case
end

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    output_q <= 32'b0;
else
    output_q <= output_next_r;  // Register update

assign gpio_output_o = output_q;  // Drive external pins
```

---

## GPIO Example Walkthrough

### Complete Signal Trace

```
C Code: *(uint32_t*)0x94000008 = 0x00000001
         ↓
RISC-V LSU: mem_addr_o=0x94000008, mem_data_wr_o=0x00000001
         ↓  
AXI4 Bridge: axi_d_awaddr_o=0x94000008, axi_d_wdata_o=0x00000001
         ↓
AXI4 Arbiter: CPU data wins → axi_arb_out_awaddr_w=0x94000008
         ↓
AXI4 Tap Decode: (0x94000008 & 0xff000000) == 0x94000000 → write_port_r=5
         ↓
AXI4 Tap Switch: axi_tap_output4_awaddr_w=0x94000008, axi_tap_output4_wdata_w=0x00000001
         ↓
GPIO Module: cfg_awaddr_i=0x94000008, cfg_wdata_i=0x00000001
         ↓
GPIO Decode: cfg_awaddr_i[7:0]=0x08 == GPIO_OUTPUT → gpio_output_wr_q=1
         ↓
GPIO Register: gpio_output_q ← 0x00000001
         ↓
Hardware Pins: gpio_output_o[0] = 1'b1 (LED turns on)
```

### Timing Diagram

```
Clock    : __|‾|__|‾|__|‾|__|‾|__|‾|__
awvalid  : ______|‾‾‾‾‾‾‾|__________
awready  : ________|‾‾‾‾‾|__________  
wvalid   : ______|‾‾‾‾‾‾‾|__________
wready   : ________|‾‾‾‾‾|__________
wr_pulse : __________|‾|____________  (gpio_output_wr_q)
register : old_val______|new_val____  (gpio_output_q)
```

---

## Address Map Reference

### Global Address Map
| Range | Peripheral | Purpose |
|-------|------------|---------|
| `0x8000_0000 - 0x8fff_ffff` | Main Memory | DDR/SRAM (external) |
| `0x9000_0000 - 0x90ff_ffff` | IRQ Controller | Interrupt management |
| `0x9100_0000 - 0x91ff_ffff` | Timer | System timers |
| `0x9200_0000 - 0x92ff_ffff` | UART | Serial communication |
| `0x9300_0000 - 0x93ff_ffff` | SPI | SPI interface |
| `0x9400_0000 - 0x94ff_ffff` | GPIO | General purpose I/O |
| `0x9500_0000 - 0x95ff_ffff` | **Available** | **Your LED registers here** |

### GPIO Register Map
| Address | Register | Access | Purpose |
|---------|----------|--------|---------|
| `0x9400_0000` | GPIO_DIRECTION | R/W | Pin direction (0=input, 1=output) |
| `0x9400_0004` | GPIO_INPUT | R | Read pin states |
| `0x9400_0008` | GPIO_OUTPUT | R/W | Write pin states |
| `0x9400_000c` | GPIO_OUTPUT_SET | W | Set specific bits (OR operation) |
| `0x9400_0010` | GPIO_OUTPUT_CLR | W | Clear specific bits (AND ~mask) |
| `0x9400_0014` | GPIO_INT_MASK | R/W | Interrupt enable mask |
| `0x9400_0018` | GPIO_INT_SET | W | Software interrupt trigger |
| `0x9400_001c` | GPIO_INT_CLR | W | Interrupt acknowledge |
| `0x9400_0020` | GPIO_INT_STATUS | R | Raw interrupt status |
| `0x9400_0024` | GPIO_INT_LEVEL | R/W | Interrupt polarity |
| `0x9400_0028` | GPIO_INT_MODE | R/W | Edge vs level interrupt |

---

## Adding Custom Peripherals

### Method 1: Extend GPIO Address Space

Add registers at unused GPIO addresses (e.g., `0x9400_0030+`):

```verilog
// In gpio_defs.v
`define LED_CONTROL    8'h30   // 0x94000030
`define LED_STATUS     8'h34   // 0x94000034
`define LED_BRIGHTNESS 8'h38   // 0x94000038

// In gpio.v - add decode logic
else if (write_en_w && (cfg_awaddr_i[7:0] == `LED_CONTROL))
    led_control_wr_q <= 1'b1;
```

### Method 2: New Peripheral Slot

**Step 1**: Add peripheral5 to AXI tap (`axi4_lite_tap.v`):

```verilog
// Add constants
`define PERIPH5_ADDR         32'h95000000  
`define PERIPH5_MASK         32'hff000000

// Add to decode logic
if ((inport_awaddr_i & `PERIPH5_MASK) == `PERIPH5_ADDR) write_port_r = `ADDR_SEL_W'd6;

// Add switching logic  
assign outport_peripheral5_awvalid_o = inport_awvalid_i & write_accept_w & (write_port_r == `ADDR_SEL_W'd6);
assign outport_peripheral5_awaddr_o  = inport_awaddr_i;
assign outport_peripheral5_wvalid_o  = inport_wvalid_i & write_accept_w & (write_port_r == `ADDR_SEL_W'd6);
// ... etc
```

**Step 2**: Create LED peripheral (`led_controller.v`):

```verilog
module led_controller (
    // Standard AXI4-Lite slave interface  
    input           clk_i,
    input           rst_i,
    input           cfg_awvalid_i,
    input  [31:0]   cfg_awaddr_i,
    input           cfg_wvalid_i,
    input  [31:0]   cfg_wdata_i,
    input  [3:0]    cfg_wstrb_i,
    input           cfg_bready_i,
    input           cfg_arvalid_i,
    input  [31:0]   cfg_araddr_i,
    input           cfg_rready_i,
    
    output          cfg_awready_o,
    output          cfg_wready_o,
    output          cfg_bvalid_o,
    output [1:0]    cfg_bresp_o,
    output          cfg_arready_o,
    output          cfg_rvalid_o,
    output [31:0]   cfg_rdata_o,
    output [1:0]    cfg_rresp_o,
    
    // LED-specific outputs
    output [15:0]   led_o,
    output [7:0]    led_brightness_o
);

// Follow GPIO pattern exactly...
wire write_en_w = cfg_awvalid_i & cfg_awready_o;

// Register decode
`define LED_DATA       8'h0
`define LED_BRIGHTNESS 8'h4
`define LED_BLINK      8'h8

// Register implementations
reg [15:0] led_data_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    led_data_q <= 16'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `LED_DATA))
    led_data_q <= cfg_wdata_i[15:0];

assign led_o = led_data_q;
// ... implement other registers

endmodule
```

**Step 3**: Instantiate in SoC (`soc.v`):

```verilog
led_controller u_leds (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .cfg_awvalid_i(axi_tap_output5_awvalid_w),
    .cfg_awaddr_i(axi_tap_output5_awaddr_w),
    .cfg_wvalid_i(axi_tap_output5_wvalid_w),
    .cfg_wdata_i(axi_tap_output5_wdata_w),
    .cfg_wstrb_i(axi_tap_output5_wstrb_w),
    .cfg_bready_i(axi_tap_output5_bready_w),
    .cfg_arvalid_i(axi_tap_output5_arvalid_w),
    .cfg_araddr_i(axi_tap_output5_araddr_w),
    .cfg_rready_i(axi_tap_output5_rready_w),
    
    .cfg_awready_o(axi_tap_output5_awready_w),
    .cfg_wready_o(axi_tap_output5_wready_w),
    .cfg_bvalid_o(axi_tap_output5_bvalid_w),
    .cfg_bresp_o(axi_tap_output5_bresp_w),
    .cfg_arready_o(axi_tap_output5_arready_w),
    .cfg_rvalid_o(axi_tap_output5_rvalid_w),
    .cfg_rdata_o(axi_tap_output5_rdata_w),
    .cfg_rresp_o(axi_tap_output5_rresp_w),
    
    .led_o(led_output_o),
    .led_brightness_o(led_brightness_o)
);
```

### Software Usage

```c
// GPIO control
#define GPIO_BASE    0x94000000
#define GPIO_OUTPUT  (GPIO_BASE + 0x08)

// LED control  
#define LED_BASE       0x95000000
#define LED_DATA       (LED_BASE + 0x00)  
#define LED_BRIGHTNESS (LED_BASE + 0x04)
#define LED_BLINK      (LED_BASE + 0x08)

// Turn on GPIO pin 0
*(volatile uint32_t*)GPIO_OUTPUT = 0x00000001;

// Turn on LEDs 0, 2, 4
*(volatile uint32_t*)LED_DATA = 0x0015;  // Binary: 0000000000010101

// Set brightness to 50%
*(volatile uint32_t*)LED_BRIGHTNESS = 128;

// Enable blinking on LED 0
*(volatile uint32_t*)LED_BLINK = 0x0001;
```

---

## Key Design Patterns

### 1. AXI4-Lite Slave Interface Template

Every peripheral must implement this exact interface:

```verilog
module my_peripheral (
    // Clock and reset
    input           clk_i,
    input           rst_i,
    
    // AXI4-Lite slave interface
    input           cfg_awvalid_i,    // Write address valid
    input  [31:0]   cfg_awaddr_i,     // Write address
    input           cfg_wvalid_i,     // Write data valid  
    input  [31:0]   cfg_wdata_i,      // Write data
    input  [3:0]    cfg_wstrb_i,      // Write strobes
    input           cfg_bready_i,     // Response ready
    input           cfg_arvalid_i,    // Read address valid
    input  [31:0]   cfg_araddr_i,     // Read address
    input           cfg_rready_i,     // Read ready
    
    output          cfg_awready_o,    // Write address ready
    output          cfg_wready_o,     // Write data ready
    output          cfg_bvalid_o,     // Write response valid
    output [1:0]    cfg_bresp_o,      // Write response
    output          cfg_arready_o,    // Read address ready
    output          cfg_rvalid_o,     // Read data valid
    output [31:0]   cfg_rdata_o,      // Read data
    output [1:0]    cfg_rresp_o,      // Read response
    
    // Peripheral-specific I/O
    output [N-1:0]  my_outputs_o,
    input  [M-1:0]  my_inputs_i
);
```

### 2. Register Implementation Pattern

```verilog
// Write detection
wire write_en_w = cfg_awvalid_i & cfg_awready_o;

// Register decode  
`define MY_REG_ADDR  8'h0
reg my_reg_wr_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    my_reg_wr_q <= 1'b0;
else if (write_en_w && (cfg_awaddr_i[7:0] == `MY_REG_ADDR))
    my_reg_wr_q <= 1'b1;
else
    my_reg_wr_q <= 1'b0;

// Register storage
reg [31:0] my_reg_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    my_reg_q <= 32'h0;
else if (my_reg_wr_q)
    my_reg_q <= cfg_wdata_i;
```

### 3. Read Mux Pattern

```verilog
reg [31:0] data_r;

always @ * begin
    data_r = 32'b0;
    
    case (cfg_araddr_i[7:0])
        `MY_REG0: data_r = my_reg0_q;
        `MY_REG1: data_r = my_reg1_q;  
        `MY_REG2: data_r = my_inputs_i;  // Read-only register
        default:  data_r = 32'b0;
    endcase
end

// Read response logic
reg [31:0] rd_data_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    rd_data_q <= 32'b0;
else if (!cfg_rvalid_o || cfg_rready_i)
    rd_data_q <= data_r;

assign cfg_rdata_o = rd_data_q;
```

---

## File Reference

### Core Files
| File | Purpose | Key Content |
|------|---------|-------------|
| `core/core/rv32im/riscv_lsu.v` | Load-Store Unit | CPU memory interface generation |
| `core/top_tcm_axi/src_v/riscv_tcm_top.v` | CPU wrapper | AXI4 bridge logic |
| `soc/riscv_soc.v` | SoC top level | CPU instantiation and AXI conversion |

### Bus Infrastructure  
| File | Purpose | Key Content |
|------|---------|-------------|
| `soc/axi4_arb.v` | AXI4 arbiter | Multi-master arbitration logic |
| `soc/axi4_lite_tap.v` | Address decoder | Peripheral selection and routing |
| `soc/soc.v` | System integration | All peripheral instantiations |

### Peripheral Examples
| File | Purpose | Key Content |
|------|---------|-------------|
| `soc/gpio.v` | GPIO implementation | Register decode, write logic, I/O control |
| `soc/gpio_defs.v` | GPIO registers | Address offsets and bit definitions |
| `soc/timer.v` | Timer peripheral | Alternative peripheral example |
| `soc/uart_lite.v` | UART peripheral | Another peripheral reference |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | System overview, memory map, register descriptions |
| `REGISTER_ARCHITECTURE_GUIDE.md` | This document |

---

## Quick Reference Commands

### Common Register Operations

```c
// Read GPIO input
uint32_t inputs = *(volatile uint32_t*)0x94000004;

// Write GPIO output  
*(volatile uint32_t*)0x94000008 = 0x0000FFFF;

// Set GPIO direction (1=output, 0=input)
*(volatile uint32_t*)0x94000000 = 0x0000FFFF;

// Set specific GPIO bits (non-destructive)
*(volatile uint32_t*)0x9400000C = 0x00000001;  // Set bit 0

// Clear specific GPIO bits (non-destructive)  
*(volatile uint32_t*)0x94000010 = 0x00000001;  // Clear bit 0

// Read timer value
uint32_t time = *(volatile uint32_t*)0x91000010;

// UART transmit
*(volatile uint32_t*)0x92000004 = 'A';  // Send character 'A'
```

### Debugging Tips

1. **Check AXI handshaking**: Ensure `*valid` and `*ready` signals align
2. **Verify address decode**: Use `write_port_r` signal in simulation  
3. **Monitor register writes**: Watch `*_wr_q` pulse signals
4. **Trace signal flow**: Follow naming convention through hierarchy

### Signal Naming Convention

- `*_i` = Input to module
- `*_o` = Output from module  
- `*_w` = Wire (combinational)
- `*_q` = Register (clocked)
- `*_r` = Combinational logic result

---

*This guide covers the complete register architecture of the RISC-V SoC. Use it as a reference when implementing custom peripherals, debugging bus issues, or understanding the system's memory-mapped I/O design.*