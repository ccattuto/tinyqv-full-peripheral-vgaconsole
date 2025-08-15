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

    localparam [1:0] DEFAULT_TEXT_COLOR = 2'b00;
    localparam [5:0] DEFAULT_BG_COLOR = 6'b000000;

    // Text buffer (printable ASCII code in the lowest 7 bits, color in the top 2 bits)
    reg [8:0] text[0:NUM_CHARS-1];
    reg [5:0] bg_color;

    // ----- HOST INTERFACE -----
    
    wire in_text_range = (address < NUM_CHARS);
    wire any_write = ~(data_write_n[1] & data_write_n[0]);
    wire we_text = in_text_range & any_write;
    wire we_bg = &address & any_write;

    // byte writes use the default text color, wider writes also provide color bits
    wire [1:0] next_color = (data_write_n == 2'b00) ? DEFAULT_TEXT_COLOR : data_in[9:8];

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

    localparam [9:0] VGA_WIDTH = 640;
    localparam [9:0] VGA_HEIGHT = 480;
    localparam [9:0] VGA_FRAME_XMIN = 80;
    localparam [9:0] VGA_FRAME_XMAX = VGA_WIDTH - 80;
    localparam [9:0] VGA_FRAME_YMIN = 128;
    localparam [9:0] VGA_FRAME_YMAX = VGA_HEIGHT - 160;

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


    // compute (x,y) coordinates relative to frame, and frame_active flag

    wire [10:0] pix_x_diff = {1'b0, pix_x} - {1'b0, VGA_FRAME_XMIN};
    wire pix_x_below_xmin = pix_x_diff[10];     // pix_x < XMIN

    wire [10:0] pix_y_diff = {1'b0, pix_y} - {1'b0, VGA_FRAME_YMIN};
    wire pix_y_below_ymin = pix_y_diff[10];     // pix_y < YMIN
    wire [5:0] pix_y_frame = pix_y_diff[8:3];   // (pix_y - YMIN) / 8

    wire frame_active = ~(pix_x_below_xmin | pix_y_below_ymin) && (pix_x < VGA_FRAME_XMAX) && (pix_y < VGA_FRAME_YMAX);

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
        if (&pix_x_diff) begin  // pix_x == VGA_FRAME_XMIN - 1
            rel_x <= 0;
            cnt1 <= 0;
            char_x <= 0;
        end else begin
            cnt1 <= cnt1 + 1;
            if (&cnt1) begin
                if (rel_x_5) begin
                    rel_x <= 0;
                    char_x <= char_x + 1;
                end else begin
                    rel_x <= rel_x + 1;
                end
            end
        end
    end

    // reg [5:0] cx48;
    // reg [COLS_ADDR_WIDTH-1:0] char_x;

    // always @(posedge clk) begin
    //     if (&pix_x_diff) begin  // pix_x == VGA_FRAME_XMIN - 1
    //         cx48 <= 0;
    //         char_x <= 0;
    //     end else begin
    //         if (cx48 == 47) begin
    //             cx48 <= 0;
    //             char_x <= char_x + 1;
    //         end else begin
    //             cx48 <= cx48 + 1;
    //         end
    //     end
    // end

    // wire [2:0] rel_x = cx48[5:3];
    // wire rel_x_5 = (rel_x == 3'd5);

    // Row of current character in the NUM_ROWS x NUM_COLS text buffer
    wire [ROWS_ADDR_WIDTH-1:0] char_y = pix_y_frame[3+ROWS_ADDR_WIDTH-1:3];  // divide by 64 (VGA char height is 64 pixels)

    // Here we hardcode NUM_COLS = 10 to save gates, the general case is: text[char_y * NUL_COLS + char_x]
    wire [4:0] char_addr = ({{(5-ROWS_ADDR_WIDTH){1'b0}}, char_y} << 3) + ({{(5-ROWS_ADDR_WIDTH){1'b0}},char_y} << 1) + char_x;
    wire [8:0] char = text[char_addr];
    wire [6:0] char_index = char[6:0];  // Drive character ROM input
    wire [1:0] char_color = char[8:7];  // Character color

    // Current pixel's y coordinate within current character (5x7 glyph padded in a 6x8 character box)
    wire [2:0] rel_y = pix_y_frame[2:0];  // remainder of division by 8

    // Current pixel index in the 35-bit wide character ROM (rel_y * 5 + rel_x)
    wire [5:0] offset = ({3'b0, rel_y} << 2) + {3'b0, rel_y} + {3'b0, rel_x};

    // Current pixel's state in character ROM,
    // handling 1-pixel padding along x and y directions.
    wire char_pixel = (&rel_y || rel_x_5) ? 0 : char_data[offset];

    // Generate RGB signals
    wire pixel_on = frame_active & char_pixel;
    wire [2:0] pixel_color = color_rom[char_color];
    wire [5:0] char_bgr = { {2{pixel_color[2]}}, {2{pixel_color[1]}}, {2{pixel_color[0]}} };
    assign {B, G, R} = ~video_active ? 6'b0 : (pixel_on ? char_bgr : bg_color);


    // ----- CHARACTER ROM -----

    wire [34:0] char_data;

    char_rom char_rom_inst (
        .address(char_index),
        .data(char_data) 
    );

    reg [2:0] color_rom[4];
    initial begin
        color_rom[2'b00]  = 3'b010;  // green
        color_rom[2'b01]  = 3'b101;  // magenta
        color_rom[2'b10]  = 3'b110;  // teal
        color_rom[2'b11]  = 3'b011;  // yellow
    end

endmodule
