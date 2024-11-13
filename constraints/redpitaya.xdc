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
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports adc_clk_*_i]
set_property direction IN [get_ports {adc_clk_*_i}]
set_property PACKAGE_PIN U18 [get_ports adc_clk_p_i]
set_property PACKAGE_PIN U19 [get_ports adc_clk_n_i]

# Internal ADC
# Clock output
set_property IOSTANDARD LVCMOS18 [get_ports adc_enc_*_o]
set_property SLEW FAST [get_ports adc_enc_*_o]
set_property DRIVE 8 [get_ports adc_enc_*_o]
set_property PACKAGE_PIN N20 [get_ports adc_enc_p_o]
set_property PACKAGE_PIN P20 [get_ports adc_enc_n_o]
# Clock duty cycle stabilizer (CSn)
set_property IOSTANDARD LVCMOS18 [get_ports adc_csn_o]
set_property SLEW FAST [get_ports adc_csn_o]
set_property DRIVE 8 [get_ports adc_csn_o]
set_property PACKAGE_PIN V18 [get_ports adc_csn_o]
# Data
set_property IOSTANDARD LVCMOS18 [get_ports {adc_dat_*_i[*]}]
set_property IOB TRUE [get_ports {adc_dat_*_i[*]}]
set_property PACKAGE_PIN V17 [get_ports {adc_dat_a_i[0]}]
set_property PACKAGE_PIN U17 [get_ports {adc_dat_a_i[1]}]
set_property PACKAGE_PIN Y17 [get_ports {adc_dat_a_i[2]}]
set_property PACKAGE_PIN W16 [get_ports {adc_dat_a_i[3]}]
set_property PACKAGE_PIN Y16 [get_ports {adc_dat_a_i[4]}]
set_property PACKAGE_PIN W15 [get_ports {adc_dat_a_i[5]}]
set_property PACKAGE_PIN W14 [get_ports {adc_dat_a_i[6]}]
set_property PACKAGE_PIN Y14 [get_ports {adc_dat_a_i[7]}]
set_property PACKAGE_PIN W13 [get_ports {adc_dat_a_i[8]}]
set_property PACKAGE_PIN V12 [get_ports {adc_dat_a_i[9]}]
set_property PACKAGE_PIN V13 [get_ports {adc_dat_a_i[10]}]
set_property PACKAGE_PIN T14 [get_ports {adc_dat_a_i[11]}]
set_property PACKAGE_PIN T15 [get_ports {adc_dat_a_i[12]}]
set_property PACKAGE_PIN V15 [get_ports {adc_dat_a_i[13]}]
set_property PACKAGE_PIN T16 [get_ports {adc_dat_a_i[14]}]
set_property PACKAGE_PIN V16 [get_ports {adc_dat_a_i[15]}]
set_property PACKAGE_PIN T17 [get_ports {adc_dat_b_i[0]}]
set_property PACKAGE_PIN R16 [get_ports {adc_dat_b_i[1]}]
set_property PACKAGE_PIN R18 [get_ports {adc_dat_b_i[2]}]
set_property PACKAGE_PIN P16 [get_ports {adc_dat_b_i[3]}]
set_property PACKAGE_PIN P18 [get_ports {adc_dat_b_i[4]}]
set_property PACKAGE_PIN N17 [get_ports {adc_dat_b_i[5]}]
set_property PACKAGE_PIN R19 [get_ports {adc_dat_b_i[6]}]
set_property PACKAGE_PIN T20 [get_ports {adc_dat_b_i[7]}]
set_property PACKAGE_PIN T19 [get_ports {adc_dat_b_i[8]}]
set_property PACKAGE_PIN U20 [get_ports {adc_dat_b_i[9]}]
set_property PACKAGE_PIN V20 [get_ports {adc_dat_b_i[10]}]
set_property PACKAGE_PIN W20 [get_ports {adc_dat_b_i[11]}]
set_property PACKAGE_PIN W19 [get_ports {adc_dat_b_i[12]}]
set_property PACKAGE_PIN Y19 [get_ports {adc_dat_b_i[13]}]
set_property PACKAGE_PIN W18 [get_ports {adc_dat_b_i[14]}]
set_property PACKAGE_PIN Y18 [get_ports {adc_dat_b_i[15]}]

# Internal DAC
set_property IOSTANDARD LVCMOS33 [get_ports {dac_dat_o[*]}]
set_property SLEW FAST [get_ports {dac_dat_o[*]}]
set_property DRIVE 8 [get_ports {dac_dat_o[*]}]
set_property PACKAGE_PIN M19 [get_ports {dac_dat_o[0]}]
set_property PACKAGE_PIN M20 [get_ports {dac_dat_o[1]}]
set_property PACKAGE_PIN L19 [get_ports {dac_dat_o[2]}]
set_property PACKAGE_PIN L20 [get_ports {dac_dat_o[3]}]
set_property PACKAGE_PIN K19 [get_ports {dac_dat_o[4]}]
set_property PACKAGE_PIN J19 [get_ports {dac_dat_o[5]}]
set_property PACKAGE_PIN J20 [get_ports {dac_dat_o[6]}]
set_property PACKAGE_PIN H20 [get_ports {dac_dat_o[7]}]
set_property PACKAGE_PIN G19 [get_ports {dac_dat_o[8]}]
set_property PACKAGE_PIN G20 [get_ports {dac_dat_o[9]}]
set_property PACKAGE_PIN F19 [get_ports {dac_dat_o[10]}]
set_property PACKAGE_PIN F20 [get_ports {dac_dat_o[11]}]
set_property PACKAGE_PIN D20 [get_ports {dac_dat_o[12]}]
set_property PACKAGE_PIN D19 [get_ports {dac_dat_o[13]}]
# Control
set_property IOSTANDARD LVCMOS33 [get_ports dac_*_o]
set_property SLEW FAST [get_ports dac_*_o]
set_property DRIVE 8 [get_ports dac_*_o]
set_property PACKAGE_PIN M17 [get_ports dac_wrt_o]
set_property PACKAGE_PIN N16 [get_ports dac_sel_o]
set_property PACKAGE_PIN M18 [get_ports dac_clk_o]
set_property PACKAGE_PIN N15 [get_ports dac_rst_o]
# PWM
set_property IOSTANDARD LVCMOS18 [get_ports {dac_pwm_o[*]}]
set_property SLEW FAST [get_ports {dac_pwm_o[*]}]
set_property DRIVE 12 [get_ports {dac_pwm_o[*]}]
set_property IOB TRUE [get_ports {dac_pwm_o[*]}]
set_property PACKAGE_PIN T10 [get_ports {dac_pwm_o[0]}]
set_property PACKAGE_PIN T11 [get_ports {dac_pwm_o[1]}]
set_property PACKAGE_PIN P15 [get_ports {dac_pwm_o[2]}]
set_property PACKAGE_PIN U13 [get_ports {dac_pwm_o[3]}]

# LEDs
set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]
set_property SLEW SLOW [get_ports {led_o[*]}]
set_property DRIVE 4 [get_ports {led_o[*]}]
set_property direction OUT [get_ports {led_o[*]}]
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
set_property IOSTANDARD LVCMOS33 [get_ports exp_adc_*]
set_property SLEW FAST [get_ports exp_adc_*]
set_property DRIVE 8 [get_ports exp_adc_*]
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
set_property PULLTYPE PULLDOWN [get_ports exp_adc_diffamp_en_o]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_io_en_o]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_opamp_en_o]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_pwr_en_o]
set_property PULLTYPE PULLDOWN [get_ports exp_adc_ref_en_o]
set_property PACKAGE_PIN L16 [get_ports exp_adc_ref_en_o]
set_property PACKAGE_PIN K16 [get_ports exp_adc_pwr_en_o]
set_property PACKAGE_PIN J16 [get_ports exp_adc_io_en_o]
set_property PACKAGE_PIN M14 [get_ports exp_adc_diffamp_en_o]
set_property PACKAGE_PIN M15 [get_ports exp_adc_opamp_en_o]

# XADC (expansion connector E2)
set_property IOSTANDARD LVCMOS33 [get_ports vaux*_v_*]
set_property IOSTANDARD LVCMOS33 [get_ports vp_vn_*]
set_property PACKAGE_PIN K9  [get_ports vp_vn_v_p]
set_property PACKAGE_PIN L10 [get_ports vp_vn_v_n]
set_property PACKAGE_PIN C20 [get_ports vaux0_v_p]
set_property PACKAGE_PIN B20 [get_ports vaux0_v_n]
set_property PACKAGE_PIN E17 [get_ports vaux1_v_p]
set_property PACKAGE_PIN D18 [get_ports vaux1_v_n]
set_property PACKAGE_PIN B19 [get_ports vaux8_v_p]
set_property PACKAGE_PIN A20 [get_ports vaux8_v_n]
set_property PACKAGE_PIN E18 [get_ports vaux9_v_p]
set_property PACKAGE_PIN E19 [get_ports vaux9_v_n]

# SATA connectors
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports daisy_*_*[*]]
# make_diff_pair_ports daisy_p_o[0] daisy_n_o[0]
# make_diff_pair_ports daisy_p_o[1] daisy_n_o[1]
# make_diff_pair_ports daisy_p_i[0] daisy_n_i[0]
# make_diff_pair_ports daisy_p_i[1] daisy_n_i[1]
set_property PACKAGE_PIN T12 [get_ports {daisy_p_o[0]}]
set_property PACKAGE_PIN U12 [get_ports {daisy_n_o[0]}]
set_property PACKAGE_PIN U14 [get_ports {daisy_p_o[1]}]
set_property PACKAGE_PIN U15 [get_ports {daisy_n_o[1]}]
set_property PACKAGE_PIN P14 [get_ports {daisy_p_i[0]}]
set_property PACKAGE_PIN R14 [get_ports {daisy_n_i[0]}]
set_property PACKAGE_PIN N18 [get_ports {daisy_p_i[1]}]
set_property PACKAGE_PIN P19 [get_ports {daisy_n_i[1]}]

