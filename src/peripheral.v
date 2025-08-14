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

    localparam [2:0] DEFAULT_TEXT_COLOR = 3'b010;
    localparam [5:0] DEFAULT_BG_COLOR = 6'b010000;

    // Text buffer (7-bit chars)
    reg [9:0] text[0:NUM_CHARS-1];
    reg [5:0] bg_color;

    // ----- HOST INTERFACE -----
    
    wire in_text_range = (address < NUM_CHARS);
    wire any_write = ~(data_write_n[1] & data_write_n[0]);
    wire we_text = in_text_range & any_write;
    wire we_bg = (address == 6'h3F) & any_write;

    // byte writes use the default text color, wider writes also provide color bits
    wire [2:0] next_color = (data_write_n == 2'b00) ? DEFAULT_TEXT_COLOR : data_in[10:8];

    always @(posedge clk) begin
        if (!rst_n)
            bg_color <= DEFAULT_BG_COLOR;
        else if (we_bg)
            bg_color <= data_in[5:0];
    end

    // Handle writes to character/color registers
    always @(posedge clk) begin
        if (we_text) begin
            text[address[CHARS_ADDR_WIDTH-1:0]] <= {next_color, data_in[6:0]};
        end
    end

    // Register reads
    assign data_out = 0;

    // All reads complete in 1 clock
    assign data_ready = 1;

    // No interrupt handling
    assign user_interrupt = 0;

    wire _unused = &{data_read_n, 1'b0};


    // ----- VGA INTERFACE -----

    localparam VGA_WIDTH = 640;
    localparam VGA_HEIGHT = 480;
    localparam VGA_FRAME_XMIN = 80;
    localparam VGA_FRAME_XMAX = VGA_WIDTH - 80;
    localparam VGA_FRAME_YMIN = 128;
    localparam VGA_FRAME_YMAX = VGA_HEIGHT - 160;

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

    wire frame_active = (pix_x >= VGA_FRAME_XMIN && pix_x < VGA_FRAME_XMAX && pix_y >= VGA_FRAME_YMIN && pix_y < VGA_FRAME_YMAX);

    // (x,y) coordinates relative to frame
    wire [9:0] pix_x_frame, pix_y_frame;
    assign pix_x_frame = pix_x - VGA_FRAME_XMIN;
    assign pix_y_frame = pix_y - VGA_FRAME_YMIN;

    // Character pixels are 8x8 squares in the VGA frame.
    // Character glyphs are 5x7 and padded in a 6x8 character box.
 
    // char_x is column of current character in the NUM_ROWS x NUM_COLS text buffer,
    // rel_x is current pixel's x coordinate within current character.
    // We use counters to avoid divisions and remainders.
    reg [2:0] rel_x;
    wire rel_x_5 = (rel_x == 3'd5);
    reg [2:0] cnt1;
    reg [COLS_ADDR_WIDTH-1:0] char_x;
    always @(posedge clk) begin
        if (pix_x == VGA_FRAME_XMIN-1) begin
            cnt1   <= 0;
            rel_x  <= 0;
            char_x <= '0;
        end else begin
            cnt1 <= cnt1 + 1;
            if (&cnt1) begin
                rel_x  <= rel_x_5 ? 0 : rel_x + 1;
                char_x <= char_x + rel_x_5;
            end
        end
    end

    // Row of current character in the NUM_ROWS x NUM_COLS text buffer
    wire [ROWS_ADDR_WIDTH-1:0] char_y = pix_y_frame[6+ROWS_ADDR_WIDTH-1:6];  // divide by 64 (VGA char height is 64 pixels)

    // Here we hardcode NUM_COLS = 10 to save gates, the general case is: text[char_y * NUL_COLS + char_x]
    wire [9:0] char  = text[({{(10-COLS_ADDR_WIDTH){1'b0}}, char_y} << 3) + ({{(10-COLS_ADDR_WIDTH){1'b0}},char_y} << 1) + char_x];
    wire [6:0] char_index = char[6:0];  // Drive character ROM input
    wire [2:0] char_color = char[9:7];  // Character color

    // Current pixel's y coordinate within current character (5x7 glyph padded in a 6x8 character box)
    wire [2:0] rel_y = pix_y_frame[5:3];  // remainder of division by 8

    // Current pixel index in the 35-bit wide character ROM (rel_y * 5 + rel_x)
    wire [5:0] offset = (rel_y << 2) + rel_y + rel_x;

    // Current pixel's state in character ROM,
    // handling 1-pixel padding along x and y directions.
    wire char_pixel = (&rel_y || rel_x_5) ? 0 : char_data[offset];

    // Generate RGB signals
    wire pixel_on = frame_active & char_pixel;
    wire [5:0] char_rgb = { {2{char_color[2]}}, {2{char_color[1]}}, {2{char_color[0]}} };
    assign {B, G, R} = ~video_active ? 6'b0 : (pixel_on ? char_rgb : bg_color);


    // ----- CHARACTER ROM -----

    wire [34:0] char_data;

    char_rom char_rom_inst (
        .address(char_index),
        .data(char_data) 
    );

endmodule
