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
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_p_i]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_n_i]
set_property PACKAGE_PIN U18 [get_ports adc_clk_p_i]
set_property PACKAGE_PIN U19 [get_ports adc_clk_n_i]
set_input_delay -max 1.000 -clock adc_clk_p_i [get_ports adc_dat_a_i[*]]
set_input_delay -max 1.000 -clock adc_clk_p_i [get_ports adc_dat_b_i[*]]

# Clock output
set_property IOSTANDARD LVCMOS18 [get_ports adc_enc_p_o]
set_property IOSTANDARD LVCMOS18 [get_ports adc_enc_n_o]
set_property SLEW FAST [get_ports adc_enc_p_o]
set_property SLEW FAST [get_ports adc_enc_n_o]
set_property DRIVE 8 [get_ports adc_enc_p_o]
set_property DRIVE 8 [get_ports adc_enc_n_o]
set_property PACKAGE_PIN N20 [get_ports adc_enc_p_o]
set_property PACKAGE_PIN P20 [get_ports adc_enc_n_o]

# Clock duty cycle stabilizer (CSn)
set_property IOSTANDARD LVCMOS18 [get_ports adc_csn_o]
set_property PACKAGE_PIN V18 [get_ports adc_csn_o]
set_property SLEW FAST [get_ports adc_csn_o]
set_property DRIVE 8 [get_ports adc_csn_o]

# LEDs
set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]
set_property SLEW SLOW [get_ports {led_o[*]}]
set_property DRIVE 4 [get_ports {led_o[*]}]

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
# GPIO connector. With the 24-bit ADC expansion board, many of the pins are
# re-purposed for use with the AD4030-24 SPI bus. 

set_property PACKAGE_PIN G17 [get_ports {exp_p_tri_io[0]}]
set_property PACKAGE_PIN G18 [get_ports {exp_n_tri_io[0]}]
set_property PACKAGE_PIN H16 [get_ports {exp_p_tri_io[1]}]
set_property PACKAGE_PIN H17 [get_ports {exp_n_tri_io[1]}]
set_property PACKAGE_PIN J18 [get_ports {exp_p_tri_io[2]}]
set_property PACKAGE_PIN H18 [get_ports {exp_n_tri_io[2]}]
set_property PACKAGE_PIN K17 [get_ports {exp_p_tri_io[3]}]
set_property PACKAGE_PIN K18 [get_ports {exp_n_tri_io[3]}]
set_property PACKAGE_PIN L14 [get_ports {exp_p_tri_io[4]}]
set_property PACKAGE_PIN L15 [get_ports {exp_n_tri_io[4]}]
set_property PACKAGE_PIN L16 [get_ports {exp_p_tri_io[5]}]
set_property PACKAGE_PIN L17 [get_ports {exp_n_tri_io[5]}]
set_property PACKAGE_PIN K16 [get_ports {exp_p_tri_io[6]}]
set_property PACKAGE_PIN J16 [get_ports {exp_n_tri_io[6]}]
set_property PACKAGE_PIN M14 [get_ports {exp_p_tri_io[7]}]
set_property PACKAGE_PIN M15 [get_ports {exp_n_tri_io[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {exp_p_tri_io[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {exp_n_tri_io[*]}]
set_property SLEW FAST [get_ports {exp_p_tri_io[*]}]
set_property SLEW FAST [get_ports {exp_n_tri_io[*]}]
set_property DRIVE 8 [get_ports {exp_p_tri_io[*]}]
set_property DRIVE 8 [get_ports {exp_n_tri_io[*]}]


