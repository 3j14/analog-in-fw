# This is taken care of by the
# create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]

create_clock -period 20.000 -name spi_clk -waveform {0.000 5.000} [get_nets bd_adc_i/clk_wiz_0_clk_out2]

# Proapagation delay derived from 
#  - TXB0106 switching characteristics, 
#  - and AD4030-24 timing specifications.
#
# Red Pitaya -> Exp. ADC: delay = [1.3, 6.8] ns
# Epx. ADC -> Red Pitaya: delay = [0.8, 7.6] ns
#
# Falling edge to data remains valid: 1.4 ns
# Falling edge to data valid delay: 5.6 ns
# Note: Use 5 ns clock high time (min is 4.2).
set_input_delay -clock [get_clocks spi_clk] -min -add_delay 7.700 [get_ports {exp_adc_sdi[*]}]
set_input_delay -clock [get_clocks spi_clk] -max -add_delay 17.4 [get_ports {exp_adc_sdi[*]}]
set_output_delay -clock [get_clocks spi_clk] -min -add_delay -0.200 [get_ports exp_adc_sdo]
set_output_delay -clock [get_clocks spi_clk] -max -add_delay 8.600 [get_ports exp_adc_sdo]
