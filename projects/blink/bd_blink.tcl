create_bd_design bd_blink

create_bd_cell -type module -reference blink blink_0

# Create clocking wizard
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIMITIVE PLL \
    CONFIG.PRIM_IN_FREQ {125.0} \
    CONFIG.PRIM_SOURCE Differential_clock_capable_pin \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.0} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
] [get_bd_cells /clk_wiz_0]

create_bd_port -dir I adc_clk_p_i
create_bd_port -dir I adc_clk_n_i
create_bd_port -dir O -from 7 -to 0 led_o

connect_bd_net [get_bd_ports led_o] [get_bd_pins blink_0/led]

connect_bd_net [get_bd_ports adc_clk_p_i] [get_bd_pins clk_wiz_0/clk_in1_p]
connect_bd_net [get_bd_ports adc_clk_n_i] [get_bd_pins clk_wiz_0/clk_in1_n]

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps_0
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins ps_0/M_AXI_GP0_ACLK]


apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
  make_external {FIXED_IO, DDR}
  Master "Disable"
  Slave "Disable"
} [get_bd_cells ps_0]

create_bd_port -dir I -type rst rst
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports rst]
connect_bd_net [get_bd_ports rst] [get_bd_pins blink_0/rst]
connect_bd_net [get_bd_ports rst] [get_bd_pins clk_wiz_0/resetn]
