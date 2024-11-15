# This is taken care of by the 
# create_clock -period 8.000 -name adc_clk [get_ports adc_clk_p_i]

create_generated_clock -name adc_sclk -source [get_pins -hier -filter name=~*sclk_reg/C] -edges {1 3 5} [get_ports exp_adc_sck]

# Proapagation delay derived from the voltage level translator data sheet
set tsetup 4.2
set thold 1.0

set_input_delay -clock_fall -min $thold -clock adc_sclk [get_ports {exp_adc_sdi[*]}]
set_input_delay -clock_fall -max $tsetup -clock adc_sclk [get_ports {exp_adc_sdi[*]}]
# set_input_delay -min $thold -clock adc_sclk [get_ports exp_adc_sck]
# set_input_delay -max $tsetup -clock adc_sclk [get_ports exp_adc_sck]

set_output_delay -min 1.5 -clock adc_sclk [get_ports {exp_adc_sdo}]
set_output_delay -max 1.5 -clock adc_sclk [get_ports {exp_adc_sdo}]

