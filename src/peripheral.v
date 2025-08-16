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

    localparam NUM_ROWS = 3;
    localparam NUM_COLS = 10;
    localparam NUM_CHARS = NUM_ROWS * NUM_COLS;
    localparam ROWS_ADDR_WIDTH = $clog2(NUM_ROWS);
    localparam COLS_ADDR_WIDTH = $clog2(NUM_COLS);
    localparam CHARS_ADDR_WIDTH = $clog2(NUM_CHARS);

    localparam REG_TEXT_COLOR = 6'h30;
    localparam REG_BG_COLOR = 6'h31;
    localparam REG_VGA = 6'h32;

    // Text buffer (7-bit chars)
    reg [6:0] text[0:NUM_CHARS-1];

    reg [5:0] text_color;   // Text color
    reg [5:0] bg_color;     // Background color
    reg transparent;        // Transparency flag
    

    // ----- HOST INTERFACE -----
    
    // Writes (only write lowest 8 bits)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bg_color <= 6'b010000;
            text_color <= 6'b001100;
            transparent <= 0;
        end else begin
            if (data_write_n != 2'b11) begin
                if (address < NUM_CHARS) begin
                    text[address[CHARS_ADDR_WIDTH-1:0]] <= data_in[6:0];
                end else if (address == REG_TEXT_COLOR) begin
                    text_color <= data_in[5:0];
                    transparent <= data_in[7];
                end else if (address == REG_BG_COLOR) begin
                    bg_color <= data_in[5:0];
                end
            end
        end
    end

    // Register reads
    assign data_out = (address < NUM_CHARS) ? {25'h0, text[address[CHARS_ADDR_WIDTH-1:0]]} : 
                      (address == REG_TEXT_COLOR) ? {24'h0, transparent, 1'b0, text_color} :
                      (address == REG_BG_COLOR) ? {26'h0, bg_color} :
                      (address == REG_VGA) ? {30'h0, vsync, blank} :
                      32'h0;

    // VGA status register
    assign clear_interrupt = (address == REG_VGA) && (data_read_n != 2'b11);

    // All reads complete in 1 clock
    assign data_ready = 1;

    // Interrupt handling
    wire vga_interrupt, clear_interrupt;
    assign user_interrupt = vga_interrupt;


    // ----- VGA INTERFACE -----

    localparam VGA_WIDTH = 1024;
    localparam VGA_HEIGHT = 768;
    localparam VGA_FRAME_XMIN = 32;
    localparam VGA_FRAME_XMAX = VGA_WIDTH - 32;
    localparam VGA_FRAME_YMIN = 192;
    localparam VGA_FRAME_YMAX = VGA_HEIGHT - 192;

    // VGA signals
    wire hsync;
    wire vsync;
    reg hsync_buf;
    reg vsync_buf;
    wire blank;
    reg [1:0] R;
    reg [1:0] G;
    reg [1:0] B;
    wire [10:0] pix_x;
    wire [10:0] pix_y;
    wire [5:0] y_lo;
    wire [4:0] y_hi;

    // TinyVGA PMOD
    assign uo_out = {hsync_buf, B[0], G[0], R[0], vsync_buf, B[1], G[1], R[1]};

    vga_timing hvsync_gen (
        .clk(clk),
        .rst_n(rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .blank(blank),
        .interrupt(vga_interrupt),
        .cli(clear_interrupt),
        .x_lo(pix_x[4:0]),
        .x_hi(pix_x[10:5]),
        .y_lo(y_lo),
        .y_hi(y_hi)
    );

    wire frame_active = ( pix_x >= VGA_FRAME_XMIN && pix_x < VGA_FRAME_XMAX &&
                            pix_y >= VGA_FRAME_YMIN && pix_y < VGA_FRAME_YMAX) ? 1 : 0;

    // (x,y) coordinates relative to frame
    assign pix_y = ({6'b0, y_hi} << 5) + ({6'b0, y_hi} << 4) + {5'b0, y_lo};  // pix_y = y_hi * 48 + y_lo
    wire [10:0] pix_y_frame = pix_y - VGA_FRAME_YMIN;

    // Character pixels are 16x16 squares in the VGA frame.
    // Character glyphs are 5x7 and padded in a 6x8 character box.

    // x position machinery
    reg [6:0] cx96;
    reg [COLS_ADDR_WIDTH-1:0] char_x;
    wire [2:0] rel_x = cx96[6:4];
    wire rel_x_5 = (rel_x == 3'd5);

    always @(posedge clk) begin
        if (pix_x == VGA_FRAME_XMIN - 1) begin  // pix_x == VGA_FRAME_XMIN - 1
            cx96 <= 0;
            char_x <= 0;
        end else begin
            if (cx96 == 95) begin
                cx96 <= 0;
                char_x <= char_x + 1;
            end else begin
                cx96 <= cx96 + 1;
            end
        end
    end

    // (x,y) character coordinates in NUM_ROWS x NUM_COLS text buffer
    wire [ROWS_ADDR_WIDTH-1:0] char_y = pix_y_frame[8:7];  // divide by 128 (VGA char height is 128 pixels)

    // Drive character ROM input
    //wire [6:0] char_index = text[char_y * NUM_COLS + char_x];
    wire [4:0] char_addr = ({{(5-ROWS_ADDR_WIDTH){1'b0}}, char_y} << 3) + ({{(5-ROWS_ADDR_WIDTH){1'b0}}, char_y} << 1) + char_x;  // we hardcode NUM_COLS = 10 to save gates
    wire [6:0] char_index = text[char_addr];

    // Character pixel coordinates relative to the 5x7 glyph padded in a 6x8 character box
    wire [2:0] rel_y = pix_y_frame[6:4];  // remainder of division by 8

    // Character pixel index in the 35-bit wide character ROM (rel_y * 5 + rel_x)
    wire [5:0] offset = ({3'b0, rel_y} << 2) + {3'b0, rel_y} + {3'b0, rel_x};

    // Look up character pixel value in character ROM,
    // handling 1-pixel padding along x and y directions.
    wire char_pixel = (&rel_y || rel_x_5) ? 1'b0 : char_data[offset];

    // Generate RGB signals
    wire pixel_on = frame_active & char_pixel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {B, G, R} <= 6'b000000;
            vsync_buf <= 0;
            hsync_buf <= 0;
        end else begin
            vsync_buf <= vsync;
            hsync_buf <= hsync;
            if (blank) begin
                {B, G, R} <= 6'b000000;
            end else begin
                {B, G, R} <= pixel_on ? (~transparent ? text_color : text_color | bg_color) : bg_color;
            end
        end
    end

    // ----- CHARACTER ROM -----

    wire [34:0] char_data;

    char_rom char_rom_inst (
        .address(char_index),
        .data(char_data) 
    );

endmodule
