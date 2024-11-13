create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]

set_input_delay -max 5.000 -clock adc_clk [get_ports exp_adc_sck]
set_input_delay -max 5.000 -clock adc_clk [get_ports {exp_adc_sdi[*]}]
set_output_delay -max 5.000 -clock adc_clk [get_ports exp_adc_cnv]
set_output_delay -max 5.000 -clock adc_clk [get_ports {exp_adc_sdo[*]}]
