<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

The peripheral index is the number TinyQV will use to select your peripheral.  You will pick a free
slot when raising the pull request against the main TinyQV repository, and can fill this in then.  You
also need to set this value as the PERIPHERAL_NUM in your test script.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# Your project title

Author: Ciro Cattuto

Peripheral index: nn

## What it does

The peripheral provides a 10x3 character VGA console supporting printable ASCII characters (32-126). The 10x3 text buffer is memory-mapped, hence it is possible to set individual characters using simple writes to the peripheral's registers.

## Register map

The 10x3 character buffer is exposed via registers `CHAR0` to `CHAR29`. When writing to a register, only the lowest 7 bits of the written value are processed. 

| Address | Name   | Access | Description                                                         |
|---------|--------|--------|---------------------------------------------------------------------|
| 0x00    | CHAR0  | R/W    | ASCII code of character at position 0                               |
| 0x01    | CHAR1  | R/W    | ASCII code of character at position 1                               |
| 0x02    | CHAR2  | R/W    | ASCII code of character at position 2                               |
| ...     | ...    | R/W    | ...                                                                 |
| 0x1B    | CHAR27 | R/W    | ASCII code of character at position 27                              |
| 0x1C    | CHAR28 | R/W    | ASCII code of character at position 28                              |
| 0x1D    | CHAR29 | R/W    | ASCII code of character at position 29                              |

## How to test

Write 65 to register CHAR0. An "A" character should appear at the top left of the VGA display.

## External hardware

[TinyVGA PMOD](https://github.com/mole99/tiny-vga) for VGA output.
