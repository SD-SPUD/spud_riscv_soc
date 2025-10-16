// hub75_64x64_flash_red_blue.v
// Alternates between solid red and solid blue on HUB75 64×64 (1/32 scan)

module matrix_core #(
  parameter ON_TIME = 20000,       // cycles each row is enabled
  parameter FLASH_PERIOD = 60,     // number of full frames before color toggles
  parameter OE_POLARITY_HIGH = 1   // 1 if OE=1 blanks panel, 0 if OE=0 blanks
) (
  input  wire sys_clk,
  input  wire sys_rstn,   // active-low reset
  input [23:0] pixel_mem [0:4095],
  output reg [14:0] matrix_output
);

localparam WIDTH      = 64;
localparam SCAN_STEPS = 32; // 64 rows / 2 halves = 32 steps

wire R1, G1, B1, R2, G2, B2, A, B, C, D, E, CLK, LAT, OE, LS_OE;  

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

// color flash logic
reg color_toggle;              // 0 = red, 1 = blue
reg [15:0] frame_counter;      // count full display refreshes

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


always @(posedge sys_clk or negedge sys_rstn) begin
  if (!sys_rstn) begin
    state         <= S_IDLE;
    col_cnt       <= 0;
    scan_idx      <= 0;
    shift_phase   <= 0;
    on_counter    <= 0;
    frame_counter <= 0;
    color_toggle  <= 0;

    R1 <= 0; G1 <= 0; B1 <= 0;
    R2 <= 0; G2 <= 0; B2 <= 0;
    A  <= 0; B  <= 0; C  <= 0; D  <= 0; E  <= 0;

    CLK <= 0;
    LAT <= 0;
    OE  <= oe_blank_val(1'b1);
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
        LAT <= 0;
        CLK <= 0;
        state <= S_SHIFT;
      end

      S_SHIFT: begin
        case (shift_phase)
          2'd0: begin
            CLK <= 0;
            LAT <= 0;
            // --- Choose color based on toggle ---
            if (color_toggle == 0) begin
              // RED
              R1 <= 1; G1 <= 0; B1 <= 0;
              R2 <= 1; G2 <= 0; B2 <= 0;
            end else begin
              // BLUE
              R1 <= 0; G1 <= 0; B1 <= 1;
              R2 <= 0; G2 <= 0; B2 <= 1;
            end
            shift_phase <= 2'd1;
          end

          2'd1: begin
            CLK <= 1; // rising edge
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
          if (scan_idx == SCAN_STEPS-1) begin
            scan_idx <= 0;
            frame_counter <= frame_counter + 1;
            // toggle color after FLASH_PERIOD full frames
            if (frame_counter >= FLASH_PERIOD) begin
              frame_counter <= 0;
              color_toggle <= ~color_toggle;
            end
          end else begin
            scan_idx <= scan_idx + 1;
          end
          state <= S_IDLE;
        end
      end
    endcase
  end
end

// always keep the level shifter enabled
assign LS_OE = 1'b1;
assign {R1, G1, B1, R2, G2, B2, A, B, C, D, E, CLK, LAT, OE, LS_OE} = matrix_output;


endmodule
