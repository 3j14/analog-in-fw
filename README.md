# Firmware for C019 24-bit ADC

[![Test HDL](https://github.com/3j14/analog-in-fw/actions/workflows/test.yml/badge.svg?event=push)](https://github.com/3j14/analog-in-fw/actions/workflows/test.yml)
[![Lint HDL](https://github.com/3j14/analog-in-fw/actions/workflows/lint.yml/badge.svg?event=push)](https://github.com/3j14/analog-in-fw/actions/workflows/lint.yml)

![3D image of the 24-bit ADC extension board](/.github/artwork/c019-24-bit-ADC-r2.png)

## Building

`make` manages the multiple stages of building the FPGA bitstream, Linux kernel,
Linux drivers, and the final Debian based image. Refer to the `Makefile`'s header
for more information on how to build the project.

### Directory structure

 - `constraints`: Vivado `xdc` constraint files, e.g. pin definitions
 - `dts`: Device tree sources, like the device tree overlay for the DMA driver
 - `library`: Verilog/SystemVerilog IPs and vendor code
 - `linux`: Patches for the Linux kernel, and the Linux kernel configuration
   - `linux/dma`: Sources for the DMADC Linux driver that manages the DMA
 - `projects`: Source files for creating the Vivado projects (mostly in TCL)
 - `scripts`: Scripts used to create the project, or build the image
 - `config.vlt`: Configuration file for Verilator
 - `Makefile`: Main entry point for `make`

### Vivado Projects
The projects are build using AMD Vivado&trade; 2024.2 release. The block designs
can be build using `make`:
```shell
make PROJECT=adc project
```
The projects are defined in `tcl` files and can also be created without `make`:
```shell
vivado -source scripts/project.tcl -tclargs adc xc7z010clg400-1 /build/projects/adc
```

## License

This project is licensed under the "BSD 3-Clause License".

The `library` directory contains additional git submodules, namely
 - [pavel-demin/red-pitaya-notes](https://github.com/pavel-demin/red-pitaya-notes),
    licensed under the MIT License by Pavel Demin,
    see [`LICENSE`](https://github.com/pavel-demin/red-pitaya-notes/blob/master/LICENSE).

Other requirements added at build time:

 - [Configfs entries for device-tree](https://github.com/Xilinx/linux-xlnx/blob/master/drivers/of/configfs.c),
   located in the Xilinx Linux source tree. Licensed under GNU General Public License
   Version 2 by Pantelis Antoniou.
 - [fpgautil](https://github.com/Xilinx/meta-xilinx/blob/master/meta-xilinx-core/recipes-bsp/fpga-manager-script/files/fpgautil.c),
   licensed under the MIT License by Xilinx, Inc.
 - [SSBL](https://github.com/pavel-demin/ssbl) by Pavel Demin.
 - [Linux kernel](https://kernel.org), licensed under the GNU General Public License version 2.
