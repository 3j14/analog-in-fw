# IPs

This directory contains intellectual property cores used throughout the project.

## Analog Devices Inc. HDI

[Analog Devices](https://analog.com/) provides [open source HDL reference designs](https://github.com/analogdevicesinc/hdl)
for use with Analog Devices ICs. Specifically, the **SPI Engine** IP core is evaluated for
reading the AD4030-24 24-bit ADC using the FPGA directly. However, it seems like the
current implementation does not support the C019 24-bit ADC expansion board. The lack
of an echo clock on the expansion board causes some timing constraint errors.

## Pavel Demin's Red Pitaya Notes

Pavel Demin has released an [in-depth guide](http://pavel-demin.github.io/red-pitaya-notes/)
and [high-quality FPGA applications](https://github.com/pavel-demin/red-pitaya-notes)
for the [Red Pitaya](https://redpitaya.com/).

