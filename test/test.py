# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock, Timer
from cocotb.triggers import Edge, ClockCycles
import numpy as np
import imageio.v2 as imageio
import random

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 0

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # VGA signals
    hsync = dut.uo_out[7]
    vsync = dut.uo_out[3]
    R0 = dut.uo_out[4]
    G0 = dut.uo_out[5]
    B0 = dut.uo_out[6]
    R1 = dut.uo_out[0]
    G1 = dut.uo_out[1]
    B1 = dut.uo_out[2]

    # 64 MHz
    clock = Clock(dut.clk, 15626, units="ps")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI test
    # harness interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset
    await tqv.reset()

    dut._log.info("Test project behavior")

    # test register write and read back
    dut._log.info("Write/read registers")
    random.seed(42)

    # clear console (all spaces)
    for i in range(30):
        await tqv.write_word_reg(i, 32)
    
    # write text
    for (i, ch) in enumerate("VGA"):  # default green
        await tqv.write_byte_reg(0+i, ord(ch))
    for (i, ch) in enumerate("CONSOLE"):  # yellow
        await tqv.write_word_reg(10+i, (0x01) << 7 | ord(ch))
    for (i, ch) in enumerate("PERIPHERAL"):  # rainbow
        await tqv.write_word_reg(20+i, (~(i & 0x03) << 7) | ord(ch))

    # grab next VGA frame and compare with reference image
    vgaframe = await grab_vga(dut, hsync, vsync, R1, R0, B1, B0, G1, G0)
    imageio.imwrite("vga_grab1.png", vgaframe * 64)
    vgaframe_ref = imageio.imread("vga_ref1.png") / 64
    assert np.all(vgaframe == vgaframe_ref)


async def grab_vga(dut, hsync, vsync, R1, R0, B1, B0, G1, G0):
    vga_frame = np.zeros((768, 1024, 3), dtype=np.uint8)

    dut._log.info("grab VGA frame: wait for vsync")
    while vsync.value == 1:
        await Edge(dut.uo_out)
    while vsync.value == 0:  # wait for vsync pulse to finish
        await Edge(dut.uo_out)
    dut._log.info("grab VGA frame: start")

    for ypos in range(27+768):
        while hsync.value == 1:
            await Edge(dut.uo_out)
        while hsync.value == 0:
            await Edge(dut.uo_out)

        if ypos < 27:
            continue

        await Timer(15625 * 151, units="ps")
        for xpos in range(1024):
            await Timer(15626 / 2 , units="ps")
            vga_frame[ypos-27][xpos][0] = R1.value << 1 | R0.value
            vga_frame[ypos-27][xpos][1] = G1.value << 1 | G0.value
            vga_frame[ypos-27][xpos][2] = B1.value << 1 | B0.value
            await Timer(15626 / 2, units="ps")

    dut._log.info("grab VGA frame: done")

    return vga_frame
