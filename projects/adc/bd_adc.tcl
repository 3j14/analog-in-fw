create_bd_design bd_${name}

set adc_clk_in_freq 125.0
set ref_clk_freq 125.0
set spi_clk_freq 50.0
set sampling_rate 1.0
set num_sdi 4

# Ports
# ADC SPI
create_bd_port -dir O exp_adc_sck
create_bd_port -dir O exp_adc_csn
create_bd_port -dir O exp_adc_resetn
create_bd_port -dir O exp_adc_sdo
create_bd_port -dir I -from [expr $num_sdi-1] -to 0 exp_adc_sdi
create_bd_port -dir I exp_adc_busy
create_bd_port -dir O exp_adc_cnv
# External clock (on Red Pitaya)
create_bd_port -dir I adc_clk_p_i
create_bd_port -dir I adc_clk_n_i

# Constants (VCC = 1, GND = 0)
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant VCC_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant GND_0
set_property CONFIG.CONST_VAL {1} [get_bd_cells VCC_0]
set_property CONFIG.CONST_VAL {0} [get_bd_cells GND_0]

# Create clocks
# Clock 1: Used for the AXI and PS
# Clock 2: Used as the SPI clock.
#   The clock is later divided down in the SPI execution engine to half
#   of the current frequency. We set it to 100.000 so that the SPI is
#   clocked at 50 MHz.
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIMITIVE PLL \
    CONFIG.PRIM_SOURCE Differential_clock_capable_pin \
    CONFIG.PRIM_IN_FREQ $adc_clk_in_freq \
    CONFIG.CLKIN1_UI_JITTER {0.0001} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $ref_clk_freq \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $spi_clk_freq \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_LOCKED {true}
] [get_bd_cells clk_wiz_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset reset

# ADC
create_bd_cell -type module -reference axis_exp_adc adc

# Connections
set ref_clk [get_bd_pins clk_wiz_0/clk_out1]
set spi_clk [get_bd_pins clk_wiz_0/clk_out2]
# Clocks
connect_bd_net [get_bd_ports adc_clk_p_i] [get_bd_pins clk_wiz_0/clk_in1_p]
connect_bd_net [get_bd_ports adc_clk_n_i] [get_bd_pins clk_wiz_0/clk_in1_n]
connect_bd_net $spi_clk [get_bd_pins adc/aclk]
connect_bd_net [get_bd_pins adc/spi_sck] [get_bd_ports exp_adc_sck]
connect_bd_net [get_bd_ports exp_adc_csn] [get_bd_pins adc/spi_csn]
connect_bd_net [get_bd_pins adc/spi_sdi] [get_bd_ports exp_adc_sdi]

regenerate_bd_layout
