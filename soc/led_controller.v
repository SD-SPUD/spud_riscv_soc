/*
File: led_controller.v
Author: Valentina Terry
Project: SPUD
Description: Provides hardware registers to control FPGA LEDs (LD2 and LD3), expected to eventually interact with display core 
Interacts with: soc/axi4_lite_tap.v (address decode logic) and soc/soc.v
Inspired by: soc/gpio.v

AXI4-Lite Interface Signals (uniform for all peripherals):
	Inputs:
	- cfg_awvalid_i, cfg_awaddr_i, cfg_wvalid_i, cfg_wdata_i, cfg_wstrb_i, cfg_bready_i
	- cfg_arvalid_i, cfg_araddr_i, cfg_rready_i
	Outputs:
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
	
	// Inputs
	input 		clk_i,
	input		rst_i,
	input		cfg_awvalid_i,
	input  [31:0]  	cfg_awaddr_i,
	input	        cfg_wvalid_i,
	input  [31:0]	cfg_wdata_i,
	input  [3:0]	cfg_wstrb_i,
	input          	cfg_bready_i,
	input          	cfg_arvalid_i,
	input  [31:0]  	cfg_araddr_i,
	input          	cfg_rready_i,

	// Outputs
	output         	cfg_awready_o,
	output         	cfg_wready_o,
	output         	cfg_bvalid_o,
	output [1:0]   	cfg_bresp_o,
	output         	cfg_arready_o,
	output         	cfg_rvalid_o,
	output [31:0]  	cfg_rdata_o,
	output [1:0]   	cfg_rresp_o,
	output [1:0]	led_o,
	output         	intr_o				
);


	// AXI4-Lite Logic (taken from gpio.v)
	//-----------------------------------------------------------------
	// Retime write data
	//-----------------------------------------------------------------
	reg [31:0] wr_data_q;

	always @ (posedge clk_i or posedge rst_i)
		if (rst_i)
    			wr_data_q <= 32'b0;
    		else
        		wr_data_q <= cfg_wdata_i;

	//-----------------------------------------------------------------
	// Request Logic
	//-----------------------------------------------------------------
	wire read_en_w  = cfg_arvalid_i & cfg_arready_o;
	wire write_en_w = cfg_awvalid_i & cfg_awready_o;

	//-----------------------------------------------------------------
	// Accept Logic
	//-----------------------------------------------------------------
	assign cfg_arready_o = ~cfg_rvalid_o;
	assign cfg_awready_o = ~cfg_bvalid_o && ~cfg_arvalid_i; 
	assign cfg_wready_o  = cfg_awready_o;

	//-----------------------------------------------------------------
	// LED_FPGA Register Logic
	//-----------------------------------------------------------------	
	
	// Internal signals
	reg [1:0] 	led_data_q;
	reg		led_data_wr_q;		
	
	// Determine if there is a valid LED write
	always @(posedge clk_i or posedge rst_i)
		if (rst_i)
			led_data_wr_q <= 1'b0;
		else
			led_data_wr_q <= write_en_w;

	// Write data to led output
	always @(posedge clk_i or posedge rst_i)
		if (rst_i)
			led_data_q <= 2'b00; 
		else if(led_data_wr_q) 	// valid write check
			led_data_q <= cfg_wdata_i[1:0];
		
	// Latch output
	assign led_o = led_data_q;

			
			


endmodule

