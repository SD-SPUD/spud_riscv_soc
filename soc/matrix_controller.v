/*
File: matrix_controller.v
Author: Valentina Terry
Project: SPUD
Description: Provides hardware registers to control LED MATRIX DISPLAY, interacts with display core 
Interacts with: soc/axi4_lite_tap.v (address decode logic) and soc/soc.v
Inspired by: soc/gpio.v

AXI4-Lite Interface Signals (uniform for all peripherals):
	Inputs:
	- cfg_awvalid_i, cfg_awaddr_i, cfg_wvalid_i, cfg_wdata_i, cfg_wstrb_i, cfg_bready_i
	- cfg_arvalid_i, cfg_araddr_i, cfg_rready_i
	Outputs:
	- cfg_awready_o, cfg_wready_o, cfg_bvalid_o, cfg_bresp_o
	- cfg_arready_o, cfg_rvalid_o, cfg_rdata_o, cfg_rresp_o

Matrix GPIO outputs:
	- TBD

Registers:
	- MATRIX_CTRL_DATA : 0x96000000: 32-bit register, 24 bits for RGB data per pixel
	- MATRIX_CTRL_ADDR : 0x96000004: 32-bit register, 12 bits for address (0 - 4095)

TO DO:
	- instantiate all required I/Os (display core)
*/



module matrix_controller (		// 64x64 matrix, 4096 pixels, 2^12 = 4096, so 12 bits required for pixel addr
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
	output [36:0]	updated_pixel_o,	// TEMP output signal for sim validation
	output [14:0]   matrix_output_o
);

localparam DISPLAY_WIDTH = 12;		// 12 bits for 4096 pixels (64x64)

`define MATRIX_CTRL_DATA 32'h96000000
`define MATRIX_CTRL_ADDR 32'h96000004

//-----------------------------------------------------------------
// Retime write datai
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

// Internal signals
reg [23:0]		pixel_write_data;
reg [DISPLAY_WIDTH-1:0] pixel_write_addr;

matrix_core #(
	.DISPLAY_WIDTH(DISPLAY_WIDTH)
) u_matrix (
	.clk_i(clk_i),
	.rst_i(rst_i),   // active-low resetz
	.pixel_write_data(pixel_write_data),
	.pixel_write_addr(pixel_write_addr),
    .matrix_output(matrix_output_o)
);

wire write_data_en = write_en_w && (cfg_awaddr_i == `MATRIX_CTRL_DATA);
wire write_addr_en = write_en_w && (cfg_awaddr_i == `MATRIX_CTRL_ADDR);

always @(posedge clk_i) begin
	if(rst_i) begin
		pixel_write_data <= 24'h0;
	end else begin
		if(write_data_en) pixel_write_data <= cfg_wdata_i[23:0];

		if (write_addr_en) pixel_write_addr <= cfg_wdata_i[DISPLAY_WIDTH-1:0];
	end
end

// assign updated_pixel_o = {write_addr_en, pixel_mem[cfg_wdata_i[DISPLAY_WIDTH-1:0]], cfg_wdata_i[DISPLAY_WIDTH-1:0]};

// TEMPORARY READ LOGIC (dummy data)
assign cfg_rvalid_o = 1'b0;
assign cfg_rdata_o  = 32'b0;
assign cfg_rresp_o  = 2'b0;

//-----------------------------------------------------------------
// BVALID (write response valid, completes the handshake)
//-----------------------------------------------------------------
reg bvalid_q;

always @ (posedge clk_i or posedge rst_i)
	if (rst_i)
		bvalid_q <= 1'b0;
	else if (write_en_w)
		bvalid_q <= 1'b1;
	else if (cfg_bready_i)
		bvalid_q <= 1'b0;

assign cfg_bvalid_o = bvalid_q;
assign cfg_bresp_o  = 2'b0;

endmodule

