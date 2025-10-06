# SPUD SOC: Adding / Updating Peripherals

This guide explains how to add new peripherals to the SPUD SOC and update the simulation/testbench accordingly.

---

## 1. RTL / FPGA Updates

When adding a new peripheral, follow these steps:

1. **Create the Peripheral Module**
   - Create a new `.v` file for your peripheral in the `/soc` folder.
   - Define all ports and logic for your peripheral in this module.

2. **Update SOC Hierarchy**
   - **`soc.v`**: Instantiate the new peripheral module and connect it to the internal signals.
   - **`riscv_soc.v`**: Add new ports corresponding to the peripheral and connect to `soc.v`.
   - **`axi4_lite_tap.v`**: Add connections for any AXI4-Lite interfaces your peripheral uses.

3. **Update FPGA Top-level**
   - **`/fpga/arty/top.v`** and **`/fpga/arty/fpga_top.v`**: Connect the peripheral signals to the top-level FPGA ports.
   - **`/fpga/arty/arty_revb.xdc`**: Assign pin constraints for the new peripheral signals.

---

## 2. Testbench Updates

1. **Signals and Bindings**
   - **`tb/testbench.h`**: Add `sc_signal`s for your new peripheral ports.
   - **`tb/riscv_soc.h`**: Connect DUT ports to the new signals.

2. **Tracing (Optional)**
   - Add new signals to the `add_trace()` method in `testbench.h` to enable waveform debugging.

---

## 3. Verilator / Simulation

1. Ensure Verilator sees the new pins if the peripheral adds signals.  
2. Re-run Verilator simulation generation:
   ```bash
   make -f makefile.generate_verilated

