/*
File: led_controller.v
Author: Valentina Terry
Project: SPUD
Description: Provides hardware registers to control FPGA LEDs (LD2 and LD3), expected to eventually interact with display core 
Interacts with: soc/axi4_lite_tap.v (address decode logic) and soc/soc.v
Inspired by: soc/gpio.v

AXI4-Lite Interface Signals (uniform for all peripherals):
	- cfg_awvalid_i, cfg_awaddr_i, cfg_wvalid_i, cfg_wdata_i, cfg_wstrb_i, cfg_bready_i
	- cfg_arvalid_i, cfg_araddr_i, cfg_rready_i
	- cfg_awready_o, cfg_wready_o, cfg_bvalid_o, cfg_bresp_o
	- cfg_arready_o, cfg_rvalid_o, cfg_rdata_o, cfg_rresp_o

LED Outputs:
	- led_o[1:0]:
		led[1] -> LD3
		led[0] -> LD2

Registers:
	- LED_FPGA (bits 0-1): control LD2 and LD3

TO DO:
	- instantiate all required I/Os
	- implement register decode and r/w logic
	- drive led outputs from reg
*/


module led_controller (
	input wire test_i,
	output reg test_o
);



endmodule

