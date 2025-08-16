`ifndef HVSYNC_GENERATOR_H
`define HVSYNC_GENERATOR_H

module hvsync_generator(
  input  wire       clk,
  input  wire       reset,
  output reg        hsync,
  output reg        vsync,
  output reg [9:0]  hpos,
  output reg [9:0]  vpos
);
  // Horizontal timing (pixels)
  parameter H_DISPLAY = 640;
  parameter H_BACK    =  48;
  parameter H_FRONT   =  16;
  parameter H_SYNC    =  96;

  // Vertical timing (lines)
  parameter V_DISPLAY = 480;
  parameter V_TOP     =  33;
  parameter V_BOTTOM  =  10;
  parameter V_SYNC    =   2;

  // Derived totals and boundaries
  localparam [9:0] H_TOTAL       = H_DISPLAY + H_BACK + H_FRONT + H_SYNC; // 800
  localparam [9:0] V_TOTAL       = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC; // 525
  localparam [9:0] H_SYNC_START  = H_DISPLAY + H_FRONT;                   // 656
  localparam [9:0] H_SYNC_END    = H_DISPLAY + H_FRONT + H_SYNC - 1;      // 751
  localparam [9:0] V_SYNC_START  = V_DISPLAY + V_BOTTOM;                  // 490
  localparam [9:0] V_SYNC_END    = V_DISPLAY + V_BOTTOM + V_SYNC - 1;     // 491

  always @(posedge clk) begin
    if (reset) begin
      hpos  <= 10'd0;
      hsync <= 1'b0;
    end else begin
      hsync <= (hpos >= H_SYNC_START) && (hpos <= H_SYNC_END);
      hpos  <= (hpos == H_TOTAL-1) ? 10'd0 : (hpos + 10'd1);
    end
  end

  wire eol = (hpos == H_TOTAL-1);

  always @(posedge clk) begin
    if (reset) begin
      vpos  <= 10'd0;
      vsync <= 1'b0;
    end else begin
      vsync <= (vpos >= V_SYNC_START) && (vpos <= V_SYNC_END);
      if (eol) begin
        vpos <= (vpos == V_TOTAL-1) ? 10'd0 : (vpos + 10'd1);
      end
    end
  end

endmodule

`endif
