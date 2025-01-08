set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_*_i]
set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]
set_property SLEW SLOW [get_ports {led_o[*]}]
set_property DRIVE 4 [get_ports {led_o[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports exp_adc_*]
# Constraints for the Red Pitaya FPGA development platform.
#
# Adapted from Pavel Demin's red-pitaya-notes. Licensed under the MIT License:
#
# The MIT License (MIT)
#
# Copyright (c) 2014-present Pavel Demin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Clock input
# make_diff_pair_ports adc_clk_p_i adc_clk_n_i
# set_property direction IN [get_ports {adc_clk_*_i}]
set_property PACKAGE_PIN U18 [get_ports adc_clk_p_i]
set_property PACKAGE_PIN U19 [get_ports adc_clk_n_i]

# Internal ADC
# Clock output
# Clock duty cycle stabilizer (CSn)
# Data

# Internal DAC
# Control
# PWM

# LEDs
# Direction is set in block design
# set_property direction OUT [get_ports {led_o[*]}]
set_property PACKAGE_PIN F16 [get_ports {led_o[0]}]
set_property PACKAGE_PIN F17 [get_ports {led_o[1]}]
set_property PACKAGE_PIN G15 [get_ports {led_o[2]}]
set_property PACKAGE_PIN H15 [get_ports {led_o[3]}]
set_property PACKAGE_PIN K14 [get_ports {led_o[4]}]
set_property PACKAGE_PIN G14 [get_ports {led_o[5]}]
set_property PACKAGE_PIN J15 [get_ports {led_o[6]}]
set_property PACKAGE_PIN J14 [get_ports {led_o[7]}]

# Expansion connector
# The original configuration set up the extension connector to be used as a
# GPIO connector. With the 24-bit ADC expansion board, the pins are
# re-purposed for use with the AD4030-24 SPI bus.
set_property OFFCHIP_TERM NONE [get_ports exp_adc_cnv]
set_property OFFCHIP_TERM NONE [get_ports exp_adc_csn]
set_property OFFCHIP_TERM NONE [get_ports exp_adc_resetn]
set_property OFFCHIP_TERM NONE [get_ports exp_adc_sck]
set_property OFFCHIP_TERM NONE [get_ports exp_adc_sdo]
set_property OFFCHIP_TERM NONE [get_ports {exp_adc_sdi[*]}]
set_property SLEW FAST [get_ports exp_adc_cnv]
set_property SLEW FAST [get_ports exp_adc_csn]
set_property SLEW FAST [get_ports exp_adc_resetn]
set_property SLEW FAST [get_ports exp_adc_sck]
set_property SLEW FAST [get_ports exp_adc_sdo]
set_property DRIVE 12 [get_ports exp_adc_cnv]
set_property DRIVE 12 [get_ports exp_adc_csn]
set_property DRIVE 12 [get_ports exp_adc_resetn]
set_property DRIVE 12 [get_ports exp_adc_sck]
set_property DRIVE 12 [get_ports exp_adc_sdo]
# SPI
set_property PACKAGE_PIN G17 [get_ports exp_adc_csn]
set_property PACKAGE_PIN G18 [get_ports exp_adc_resetn]
set_property PACKAGE_PIN H16 [get_ports exp_adc_cnv]
set_property PACKAGE_PIN H17 [get_ports exp_adc_busy]
set_property PACKAGE_PIN J18 [get_ports {exp_adc_sdi[3]}]
set_property PACKAGE_PIN H18 [get_ports {exp_adc_sdi[1]}]
set_property PACKAGE_PIN K17 [get_ports exp_adc_sck]
set_property PACKAGE_PIN K18 [get_ports {exp_adc_sdi[0]}]
set_property PACKAGE_PIN L14 [get_ports {exp_adc_sdi[2]}]
set_property PACKAGE_PIN L15 [get_ports exp_adc_sdo]
# Power enable pins
set_property PULLTYPE PULLDOWN [get_ports exp_adc_diffamp_en]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_io_en]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_opamp_en]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_pwr_en]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_ref_en]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_debug]
set_property PACKAGE_PIN L16 [get_ports exp_adc_ref_en]
set_property PACKAGE_PIN K16 [get_ports exp_adc_pwr_en]
set_property PACKAGE_PIN J16 [get_ports exp_adc_io_en]
set_property PACKAGE_PIN M14 [get_ports exp_adc_diffamp_en]
set_property PACKAGE_PIN M15 [get_ports exp_adc_opamp_en]
set_property PACKAGE_PIN L17 [get_ports exp_adc_debug]

# XADC (expansion connector E2)

# SATA connectors
# make_diff_pair_ports daisy_p_o[0] daisy_n_o[0]
# make_diff_pair_ports daisy_p_o[1] daisy_n_o[1]
# make_diff_pair_ports daisy_p_i[0] daisy_n_i[0]
# make_diff_pair_ports daisy_p_i[1] daisy_n_i[1]






