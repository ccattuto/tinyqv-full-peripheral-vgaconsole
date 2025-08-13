/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module tqvp_example (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);

    reg [6:0] text[0:35];
    
    // Implement an 8-bit write register at address 0
    always @(posedge clk) begin
        if (!rst_n) begin
            ;
        end else begin
            if ((address < 36) && (data_write_n == 2'b00)) begin
                text[address[5:0]] <= data_in[6:0];
            end
        end
    end

    assign data_out = 32'h0;

    assign data_ready = 1;

    assign user_interrupt = 0;

    wire _unused = &{data_read_n, 1'b0};


        // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
    );

    // high when the pixel belongs to the simulation rectangle
    wire frame_active;
    assign frame_active = (pix_x >= 48 && pix_x < 640-24 && pix_y >= 64 && pix_y < 480-168-64) ? 1 : 0;

    wire [5:0] rem_x;
    wire [5:0] rem_y;

    assign rem_x = pix_x[9:3] % 6;
    assign rem_y = pix_y[9:3] & 7;

    wire [5:0] offset;
    assign offset = 6'd34 - ((rem_y << 2) + rem_y + rem_x);

    wire [4:0] char_x;
    wire [1:0] char_y;
    assign char_x = ((pix_x - 48) / 6) >> 3;
    assign char_y = (pix_y - 64) >> 6;

    wire [6:0] char_index;
    assign char_index = text[char_y * 12 + char_x];

    wire char_pixel;
    assign char_pixel = ((rem_y == 7) || (rem_x == 5)) ? 0 : char_data[offset];

    // generate RGB signals
    assign R = 2'b00;
    assign G = (video_active & frame_active & char_pixel) ? 2'b11 : 2'b00;
    assign B = 2'b00;

    wire [34:0] char_data;

    char_rom char_rom_inst (
        .address(char_index),
        .data(char_data) 
    );

endmodule
