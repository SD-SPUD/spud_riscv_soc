// hub75_64x64_flash_red_blue.v
// Alternates between solid red and solid blue on HUB75 64×64 (1/32 scan)

module matrix_core #(
  parameter ON_TIME = 5000,        // cycles each row is enabled (adjusted for 25MHz)
  parameter OE_POLARITY_HIGH = 1,  // 1 if OE=1 blanks panel, 0 if OE=0 blanks
  parameter DISPLAY_WIDTH = 12     // 12 bits for 4096 pixels (64x64)
) (
  input  wire clk_i,
  input  wire rst_i,
  input  wire [23:0] pixel_write_data,   // active-low reset
  input  wire [11:0] pixel_write_addr,   // active-low reset
  output reg [14:0] matrix_output,
  output row_update_flag_o               // Flag: high during row update, low when complete
);

reg [23:0] pixel_mem [0:4095];
reg [23:0] pixel_display_data_row_1 [0:63];
reg [23:0] pixel_display_data_row_2 [0:63];
reg [11:0] pixel_index;

// Simulation only
integer i;
initial begin
    for (i = 0; i < 4096; i = i + 1)
        pixel_mem[i] = 24'h0;
end

localparam WIDTH      = 64;
localparam SCAN_STEPS = 32; // 64 rows / 2 halves = 32 steps

localparam DISPLAY_MID_INDEX = 2047;

// state machine
localparam S_IDLE  = 2'd0,
           S_SHIFT = 2'd1,
           S_LATCH = 2'd2,
           S_ON    = 2'd3;

reg [1:0] state;
reg [6:0] col_cnt;
reg [4:0] scan_idx;
reg [1:0] shift_phase;
reg [31:0] on_counter;
reg R1, G1, B1;
reg R2, G2, B2;
reg A, B, C, D, E;
reg CLK, LAT, OE;
reg flag_reg;

// color flash logic
reg [15:0] frame_counter;      // count full display refreshes


// update mem
always @(posedge clk_i) begin
    pixel_mem[pixel_write_addr] <= pixel_write_data;
end

// helper: return correct OE level for "blank"
function oe_blank_val;
  input blank;
  begin
    if (OE_POLARITY_HIGH)
      oe_blank_val = blank;
    else
      oe_blank_val = ~blank;
  end
endfunction

always @ (posedge clk_i or posedge rst_i) begin
  if (rst_i) begin
    state         <= S_IDLE;
    col_cnt       <= 0;
    scan_idx      <= 0;
    shift_phase   <= 0;
    on_counter    <= 0;
    frame_counter <= 0;
    pixel_index   <= 0;
    R1 <= 0; G1 <= 0; B1 <= 0;
    R2 <= 0; G2 <= 0; B2 <= 0;
    A  <= 0; B  <= 0; C  <= 0; D  <= 0; E  <= 0;

    CLK <= 0;
    LAT <= 0;
    OE  <= oe_blank_val(1'b1);
    flag_reg <= 1'b0;
  end else begin
    case (state)
      S_IDLE: begin
        OE <= oe_blank_val(1'b1);
        col_cnt <= 0;
        shift_phase <= 0;
        A <= scan_idx[0];
        B <= scan_idx[1];
        C <= scan_idx[2];
        D <= scan_idx[3];
        E <= scan_idx[4];
        //pixel_display_data_row_1 <= pixel_mem[{5'b0, row_cnt}];
        //pixel_display_data_row_2 <= pixel_cnt} + DISPLAY_MID_INDEX]; // optionally << 11
        LAT <= 0;
        CLK <= 0;
        state <= S_SHIFT;
      end

      S_SHIFT: begin
        case (shift_phase)
          2'd0: begin
            CLK <= 0;
            LAT <= 0;
            R1 <= pixel_mem[pixel_index][7:0] != 0;
            G1 <= pixel_mem[pixel_index][15:8] != 0;
            B1 <= pixel_mem[pixel_index][23:16] != 0;
            R2 <= pixel_mem[pixel_index + 2048][7:0] != 0;
            G2 <= pixel_mem[pixel_index + 2048][15:8] != 0;
            B2 <= pixel_mem[pixel_index + 2048][23:16] != 0;
            shift_phase <= 2'd1;
          end

          2'd1: begin
            CLK <= 1; // rising edge
            pixel_index <= pixel_index + 1;
            shift_phase <= 2'd2;
          end

          2'd2: begin
            CLK <= 0;
            if (col_cnt < WIDTH-1) begin
              col_cnt <= col_cnt + 1;
              shift_phase <= 2'd0;
            end else begin
              LAT <= 1;
              shift_phase <= 2'd0;
              state <= S_LATCH;
            end
          end

          default: begin
            shift_phase <= 2'd0;
          end
        endcase
      end

      S_LATCH: begin
        LAT <= 0;
        OE  <= oe_blank_val(1'b0);
        on_counter <= 0;
        state <= S_ON;
      end

      S_ON: begin
        on_counter <= on_counter + 1;
        if (on_counter >= ON_TIME) begin
          OE <= oe_blank_val(1'b1);
          if (scan_idx == 5'd31) begin
            scan_idx <= 0;
            pixel_index <= 0;
            flag_reg <= ~flag_reg;  // Toggle flag when full display is complete
          end else begin
            scan_idx <= scan_idx + 1;
          end
          state <= S_IDLE;
        end
      end
    endcase
  end
end

// Pack all control signals into matrix_output array
// Based on pin mapping: [14]=R1, [13]=G1, [12]=B1, [11]=R2, [10]=G2, [9]=B2,
// [8]=E, [7]=A, [6]=B, [5]=C, [4]=D, [3]=CLK, [2]=LAT, [1]=OE, [0]=LS_OE
always @(*) begin
  matrix_output = {R1, G1, B1, R2, G2, B2, E, A, B, C, D, CLK, LAT, OE, 1'b1};
end

assign row_update_flag_o = flag_reg;

endmodule
