<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# VGA character console

Author: Ciro Cattuto

Peripheral index: nn

## What it does

The peripheral provides a 10x3 character VGA console supporting printable ASCII characters (32-126). The 10x3 text buffer is memory-mapped, hence it is possible to set individual characters using simple writes to the peripheral's registers. Non-printable ASCII codes are displayed as a filled block.

## Register map

- The 10x3 character buffer is exposed via registers `CHAR0` to `CHAR29`. When writing to these registers, only the lowest 7 bits of the written value are processed.
- `TXTCOL` controls the text color (6 bits, 2 bits per channel, BBGGRR order). Bit 7 control text transparency: text color is ORed with background color when bit 7 is set. The default text color is green (001100).
- `BGCOL` controls the background color (6 bits, 2 bits per channel, BBGGRR order). The default background color is dark blue (010000).
- `VGA' provides access to VGA timing signals: bits 0 and 1 expose vsync and hsync, respectively. Transitions of these signals (to high for vsync, to low for hsync) are latched in bits 2 and 3 (vsync_latched, hsync_latched), which are cleared on reading the register. Bit 4 is the blank signal. Bit 7 is writable and controls interrupt generation (disabled by default).

| Address | Name   | Access | Description                                                         |
|---------|--------|--------|---------------------------------------------------------------------|
| 0x00    | CHAR0  | R/W    | ASCII code of character at position 0                               |
| 0x01    | CHAR1  | R/W    | ASCII code of character at position 1                               |
| 0x02    | CHAR2  | R/W    | ASCII code of character at position 2                               |
| ...     | ...    | R/W    | ...                                                                 |
| 0x1B    | CHAR27 | R/W    | ASCII code of character at position 27                              |
| 0x1C    | CHAR28 | R/W    | ASCII code of character at position 28                              |
| 0x1D    | CHAR29 | R/W    | ASCII code of character at position 29                              |
| 0x30    | TXTCOL | R/W    | Text color (low 6 bits), bit 7 (T) controls transparency: TxBBGGRR  |
| 0x31    | BGCOL  | R/W    | Background color, low 6 bits: xxBBGGRR                              |
| 0x32    | VGA    | R/W    | VGA status: interrupt enable (bit 7), x, x, blank, hsync_latched, vsync_latched, hsync, vsync (bit 0) |         

## How to test

Write 65 to register CHAR0. An "A" character should appear at the top left of the VGA display.

## External hardware

[TinyVGA PMOD](https://github.com/mole99/tiny-vga) for VGA output.

![VGA console test](vga_grab.png)
