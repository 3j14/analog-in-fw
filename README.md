# Firmware for C019 24-bit ADC

![3D image of the 24-bit ADC extension board](/.github/artwork/c019-24-bit-ADC-r2.png)

## Building

The projects are build using AMD Vivado&trade; 2024.1 release.

A convenient `Makefile` is provided to build the projects.
```shell
make PROJECT=blink
```
The projects are defined in `tcl` files and can also be created without `make`:
```shell
/path/to/vivado -source scripts/project.tcl -tclargs blink xc7z010clg400-1 /build/projects/blink
```

## License

This project is licensed under the "BSD 3-Clause License".

The `library` directory contains additional git submodules, namely
 - [pavel-demin/red-pitaya-notes](https://github.com/pavel-demin/red-pitaya-notes),
    licensed under the MIT License by Pavel Demin,
    see [`LICENSE`](https://github.com/pavel-demin/red-pitaya-notes/blob/master/LICENSE).
 - [analogdevicesinc/hdl](https://github.com/analogdevicesinc/hdl),
    see [`LICENSE`](https://github.com/analogdevicesinc/hdl/blob/main/LICENSE).

