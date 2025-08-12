![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# TinyQV Full Peripheral Template for Tiny Tapeout

- [Read the documentation for project](docs/info.md)

## What is TinyQV

[TinyQV](https://github.com/TinyTapeout/ttsky25a-tinyQV) is a Risc-V CPU designed for Tiny Tapeout.

This template helps you create peripherals that can be integrated with TinyQV, and taped out for free as part of the [Risc-V peripheral challenge](https://tinytapeout.com/competitions/risc-v-peripheral/).

## What can a peripheral do?

A peripheral allows the CPU to interact with the input and output pins, or provides some additional functionality to the CPU, or both!  All sorts of things are possible - from a UART or custom sensor driver to a graphics driver or division accelerator.

Each peripheral is allocated a range in the system's memory map, so that the CPU can read data from and write data to the peripheral.  This allows the TinyQV CPU to communicate with the peripheral.

The peripheral also has access to the 8 input and 8 output pins available to Tiny Tapeout designs.  The peripheral infrastructure can select which peripheral is in control of each output pin individually, so multiple peripherals can be used together.  The bidirectional pins are not available to the peripherals as they are used by TinyQV to access the flash and RAM.

The interface to the peripheral is [here](src/peripheral.v#L12-L31).

## How do I get started?

Implement your peripheral by replacing the implementation in the [example](src/peripheral.v#L34-L84) with your own implementation.  You may create additional modules.

Test your peripheral by replacing and extending the [example test](test/test.py#L35-L77).

## Submission checklist

Before submitting your design, please check:
- You have renamed the peripheral module from `tqvp_example` to something unique that makes sense for your design.
- You have created a [test script](test/test.py) that uses the `tqv` class to read and write your design's registers.
- You have [documented your design](docs/info.md) and its registers.

## Submission process

Please raise a pull request against https://github.com/TinyTapeout/ttsky25a-tinyQV adding your peripheral.

To get started, fork that repo and clone it, then follow the steps below to add your peripheral into the project.

If you have any trouble following these steps, ask in the Tiny Tapeout Discord or in the PR.

### Add your verilog source to src/user_peripherals

* Copy the verilog files in to a subdirectory of src/user_peripherals
* Add each source file to the info.yaml source_files section

### Add your peripheral to the "Full interface peripherals" section in src/peripherals.v

Each peripheral needs to go in its own slot in.  Find an existing slot that is still set to use the `tqvp_full_example` peripheral, this example shows slot 4:

    tqvp_full_example i_user_peri04 (
        .clk(clk),
        .rst_n(rst_n),

        .ui_in(ui_in),
        .uo_out(uo_out_from_user_peri[4]),

        .address(addr_in[5:0]),
        .data_in(data_in),

        .data_write_n(data_write_n    | {2{~peri_user[4]}}),
        .data_read_n(data_read_n_peri | {2{~peri_user[4]}}),

        .data_out(data_from_user_peri[4]),
        .data_ready(data_ready_from_user_peri[4]),

        .user_interrupt(user_interrupts[4])
    );

and change the first line to match your peripheral, for example:

    tqvp_mike_cool_synth i_cool_synth04 (


### Add your test file to test/user_peripherals

* Copy the test in to a subdirectory of test/user_peripherals
* Update your test.py to set the PERIPHERAL_NUM to match the slot used in peripherals.v.
* In test/Makefile, add the name of your test to the list of user peripherals. If your test is test.py in the my_peripheral directory add this: `my_peripheral.test`

To run your test locally, first make sure you have the submodules up to date and you've installed the python requirements:

    git submodule update --init
    pip install -r test/requirements.txt

then to run your test, from the `test` directory:

    make -B my_peripheral.test

The compressed waveform will be in `my_peripheral.fst` in the `test` directory.

### Add your docs to docs/user_peripherals

* Copy your docs/info.md into this folder and rename it with the peripheral index at the start (e.g. 04_my_peripheral.md)
* Fill in the Peripheral Index in the document.

### Raise the Pull Request through GitHub

* Push your changes to your fork of ttsky25a-tinyQV.
* Raise a pull request by going to https://github.com/TinyTapeout/ttsky25a-tinyQV/pulls
* Link to your peripheral repo in the PR.

## The peripheral test harness

This template includes a test harness for your peripheral that communicates with the peripheral using SPI.  This allows you to develop and test your peripheral independently of the rest of the Risc-V SoC.

The SPI interface implemented by the test harness operates in 32-bit words.  The command has the format:
| Bits | Meaning |
| ---- | ------- |
| 31    | Read or write command: 1 for a write, 0 for a read |
| 30-29 | Transaction width 0, 1 or 2 for 8, 16 or 32 bits |
| 28-6  | Unused |
| 5-0   | The register address |

For a write the next 32 bit word transmitted is the word to write to the register.  A full 32-bits word is sent even if the requested transaction width is shorter.

For a read, the test harness reads the register and transmits it back to the SPI controller.  Again, a full 32-bit word is used even if a shorter read was performed.

### Additional outputs

In the test harness, the user_interrupt is connected to `uio[0]`, to allow your test to verify interrupt generation.  Use the function `tqv.is_interrupt_asserted()` to check this, so that the same test can work once integrated with the Risc-V core.

The data_ready output is connected to `uio[1]`, and if necessary the test infrastructure will delay the SPI read until this goes high, allowing long read delays to be tested.

## Testing your design with TinyQV

When ttsky25a is delivered, the easiest way to test your design will be with [TinyQV Micropython](https://github.com/MichaelBell/micropython/tree/tinyqv-sky25a/ports/tinyQV).  The firmware will make it easy to read and write your registers, and set the output pins to be controlled by your peripheral (this is currently a work in progress).

In order to easily use TinyQV Micropython, you will need to avoid using the in7 and out0 IOs, as these are used for the UART peripheral to communicate with Micropython.  So if you don't need to use all of the IOs then avoid using those ones.

You can also integrate directly with the [tinyQV SDK](https://github.com/MichaelBell/tinyQV-sdk/tree/ttsky25a) to create programs in C.

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- Edit [the docs](docs/info.md) and explain your design, how it works, and how to test it.
- Submit your preipheral for inclusion in TinyQV.  See the [Discord](https://tinytapeout.com/discord) for more details.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Bluesky [#tinytapeout](https://bsky.app/hashtag/TinyTapeout) [@TinyTapeout](https://bsky.app/profile/tinytapeout.com)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
