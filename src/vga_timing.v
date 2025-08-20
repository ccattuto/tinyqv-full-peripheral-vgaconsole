`default_nettype none

module vga_timing (
    input wire clk,
    input wire rst_n,
    input wire cli,
    output reg [5:0] x_hi,
    output reg [4:0] x_lo,
    output reg [4:0] y_hi,
    output reg [5:0] y_lo,
    output wire hsync,
    output wire vsync,
    output wire blank,
    output reg interrupt
);

// 1024x768 60Hz CVT (63.5 MHz pixel clock, rounded to 64 MHz) - courtesy of RebelMike

`define H_ROLL   31
`define H_FPORCH (32 * 32)
`define H_SYNC   (33 * 32 + 16)
`define H_BPORCH (36 * 32 + 24)
`define H_NEXT   (41 * 32 + 15)

`define V_ROLL   47
`define V_FPORCH (16 * 64)
`define V_SYNC   (16 * 64 + 3)
`define V_BPORCH (16 * 64 + 7)
`define V_NEXT   (16 * 64 + 29)

always @(posedge clk) begin
    if (!rst_n) begin
        x_hi <= 0;
        x_lo <= 0;
        y_hi <= 0;
        y_lo <= 0;
        interrupt <= 0;
    end else begin
        if ({x_hi, x_lo} == `H_NEXT) begin
            x_hi <= 0;
            x_lo <= 0;
        end else if (x_lo == `H_ROLL) begin
            x_hi <= x_hi + 1;
            x_lo <= 0;
        end else begin
            x_lo <= x_lo + 1;
        end
        if ({x_hi, x_lo} == `H_SYNC) begin
            if({y_hi, y_lo} == `V_NEXT) begin
                y_hi <= 0;
                y_lo <= 0;
                interrupt <= 1;
            end else if (y_lo == `V_ROLL) begin
                y_hi <= y_hi + 1;
                y_lo <= 0;
            end else begin
                y_lo <= y_lo + 1;
            end
        end

        //hsync <= !({x_hi, x_lo} >= `H_SYNC && {x_hi, x_lo} < `H_BPORCH);

        //vsync <= ({y_hi, y_lo} >= `V_SYNC && {y_hi, y_lo} < `V_BPORCH);

        //if (cli || {y_hi, y_lo} == 0) begin
        if (cli || ~((|y_hi) | (|y_lo))) begin
            interrupt <= 0;
        end
    end
end

wire xlo_ge_17 = x_lo[4] & (|x_lo[3:0]);
wire xlo_le_24 = ~(x_lo[4] & x_lo[3] & (|x_lo[2:0]));

wire hsync_region =
       ((x_hi==6'd33) &  xlo_ge_17) |
        (x_hi==6'd34)              |
        (x_hi==6'd35)              |
       ((x_hi==6'd36) &  xlo_le_24);

assign hsync = ~hsync_region;

assign vsync = (y_hi == 5'd16) & (~|y_lo[5:3]) & y_lo[2];

// assign blank = ({x_hi, x_lo} >= `H_FPORCH || {y_hi, y_lo} >= `V_FPORCH);
assign blank = x_hi[5] | y_hi[4];

endmodule
