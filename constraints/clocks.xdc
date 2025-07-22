# This is taken care of by the
# create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]

# create_clock -period 30.000 -name adc_clk -waveform {0.000 15.000} [get_nets -hierarchical adc_clk]
# create_generated_clock -source [get_pins bd_adc_i/clk_wiz_0/clk_in1_p] -edges {1 2 3} -edge_shift {0.000 1.000 12.000} [get_pins bd_adc_i/clk_wiz_0/clk_out2]

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

create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]
create_clock -period 20.000 -name adc_spi_clk -waveform {0.000 10.000} [get_nets -hierarchical adc_clk]

set_input_delay -clock [get_clocks adc_spi_clk] -clock_fall -min -add_delay 1.300 [get_ports {exp_adc_sdi[*]}]
set_input_delay -clock [get_clocks adc_spi_clk] -clock_fall -max -add_delay 12.400 [get_ports {exp_adc_sdi[*]}]
set_input_delay -clock [get_clocks adc_spi_clk] -clock_fall -min -add_delay 1.300 [get_ports exp_adc_busy]
set_input_delay -clock [get_clocks adc_spi_clk] -clock_fall -max -add_delay 12.400 [get_ports exp_adc_busy]
set_output_delay -clock [get_clocks adc_spi_clk] -min -add_delay 7.600 [get_ports exp_adc_csn]
set_output_delay -clock [get_clocks adc_spi_clk] -max -add_delay 10.600 [get_ports exp_adc_csn]
set_output_delay -clock [get_clocks adc_spi_clk] -min -add_delay 7.600 [get_ports exp_adc_sdo]
set_output_delay -clock [get_clocks adc_spi_clk] -max -add_delay 10.600 [get_ports exp_adc_sdo]
