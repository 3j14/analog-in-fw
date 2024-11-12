create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]
set_input_delay -max 1.000 -clock adc_clk [get_ports {adc_dat_*_i[*]}]
