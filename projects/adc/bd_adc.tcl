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
# Enable pins
create_bd_port -dir O exp_adc_ref_en_o
create_bd_port -dir O exp_adc_io_en_o
create_bd_port -dir O exp_adc_pwr_en_o
create_bd_port -dir O exp_adc_diffamp_en_o
create_bd_port -dir O exp_adc_opamp_en_o
# External clock (on Red Pitaya)
create_bd_port -dir I adc_clk_p_i
create_bd_port -dir I adc_clk_n_i

# Constants (VCC = 1, GND = 0)
# On older Vivado versions (pre 2024.2), use the following instead
# for VCC_0 and GND_0:
#   create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant GND_0
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 VCC_0
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 GND_0
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
    CONFIG.CLKOUT1_SEQUENCE_NUMBER {2} \
    CONFIG.CLKOUT1_DRIVES {BUFGCE} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $spi_clk_freq \
    CONFIG.CLKOUT2_REQUESTED_DUTY_CYCLE {25} \
    CONFIG.CLKOUT2_SEQUENCE_NUMBER {1} \
    CONFIG.CLKOUT2_DRIVES {BUFGCE} \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
    CONFIG.USE_CLOCK_SEQUENCING {true} \
] [get_bd_cells clk_wiz_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset reset_spi

# Processing system
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps
set_property -dict [list \
    CONFIG.PCW_IMPORT_BOARD_PRESET "library/red-pitaya-notes/cfg/red_pitaya.xml" \
    CONFIG.PCW_USE_S_AXI_ACP {1} \
    CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {1}
] [get_bd_cells ps]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
make_external {FIXED_IO, DDR}
    Master "Disable"
    Slave "Disable"
} [get_bd_cells ps]

# ADC
create_bd_cell -type module -reference axis_exp_adc adc

# AXIS clock converters
# axis_exp_adc uses the SPI clock as its AXI clock source,
# which is slower than the main AXI bus clock. A clock converter can
# be used to cross the clocking domains in and out of the ADC SPI.
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 clk_converter_in
create_bd_cell -type ip -vlnv xilinx.com:ip:axis_clock_converter:1.1 clk_converter_out
#set_property CONFIG.IS_ACLK_ASYNC.VALUE_SRC USER [get_bd_cells clk_converter_in]
#set_property CONFIG.IS_ACLK_ASYNC {0} [get_bd_cells clk_converter_in]
#set_property CONFIG.IS_ACLK_ASYNC.VALUE_SRC USER [get_bd_cells clk_converter_out]
#set_property CONFIG.IS_ACLK_ASYNC {0} [get_bd_cells clk_converter_out]

# AXI Hub
create_bd_cell -type ip -vlnv pavel-demin:user:axi_hub:1.0 hub
set_property CONFIG.CFG_DATA_WIDTH {96} [get_bd_cells hub]
set_property CONFIG.STS_DATA_WIDTH {32} [get_bd_cells hub]

# Config registers
create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 reset_adc
set_property CONFIG.DIN_FROM {0} [get_bd_cells reset_adc]
set_property CONFIG.DIN_TO {0} [get_bd_cells reset_adc]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells reset_adc]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 reset_packetizer
set_property CONFIG.DIN_FROM {1} [get_bd_cells reset_packetizer]
set_property CONFIG.DIN_TO {1} [get_bd_cells reset_packetizer]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells reset_packetizer]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 reset_dma
set_property CONFIG.DIN_FROM {2} [get_bd_cells reset_dma]
set_property CONFIG.DIN_TO {2} [get_bd_cells reset_dma]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells reset_dma]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 ref_en
set_property CONFIG.DIN_FROM {3} [get_bd_cells ref_en]
set_property CONFIG.DIN_TO {3} [get_bd_cells ref_en]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells ref_en]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 pwr_en
set_property CONFIG.DIN_FROM {4} [get_bd_cells pwr_en]
set_property CONFIG.DIN_TO {4} [get_bd_cells pwr_en]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells pwr_en]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 io_en
set_property CONFIG.DIN_FROM {5} [get_bd_cells io_en]
set_property CONFIG.DIN_TO {5} [get_bd_cells io_en]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells io_en]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 diffamp_en
set_property CONFIG.DIN_FROM {6} [get_bd_cells diffamp_en]
set_property CONFIG.DIN_TO {6} [get_bd_cells diffamp_en]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells diffamp_en]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 opamp_en
set_property CONFIG.DIN_FROM {7} [get_bd_cells opamp_en]
set_property CONFIG.DIN_TO {7} [get_bd_cells opamp_en]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells opamp_en]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 cfg_packetizer
set_property CONFIG.DIN_FROM {95} [get_bd_cells cfg_packetizer]
set_property CONFIG.DIN_TO {64} [get_bd_cells cfg_packetizer]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells cfg_packetizer]

create_bd_cell -type ip -vlnv pavel-demin:user:port_slicer:1.0 addr_dma
set_property CONFIG.DIN_FROM {63} [get_bd_cells addr_dma]
set_property CONFIG.DIN_TO {32} [get_bd_cells addr_dma]
set_property CONFIG.DIN_WIDTH {96} [get_bd_cells addr_dma]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant cfg_dma
set_property CONFIG.CONST_WIDTH {18} [get_bd_cells cfg_dma]
set_property CONFIG.CONST_VAL {262143} [get_bd_cells cfg_dma]

# AXIS packetizer & DMA
create_bd_cell -type ip -vlnv pavel-demin:user:axis_packetizer:1.0 packetizer
set_property CONFIG.AXIS_TDATA_WIDTH {32} [get_bd_cells packetizer]
set_property CONFIG.CNTR_WIDTH {32} [get_bd_cells packetizer]
set_property CONFIG.CONTINUOUS {false} [get_bd_cells packetizer]
create_bd_cell -type ip -vlnv pavel-demin:user:axis_ram_writer:1.0 dma
set_property CONFIG.ADDR_WIDTH {18} [get_bd_cells dma]
set_property CONFIG.AXI_ID_WIDTH {3} [get_bd_cells dma]
set_property CONFIG.AXIS_TDATA_WIDTH {32} [get_bd_cells dma]
set_property CONFIG.FIFO_WRITE_DEPTH {1024} [get_bd_cells dma]

# Connections
set ref_clk [get_bd_pins clk_wiz_0/clk_out1]
set spi_clk [get_bd_pins clk_wiz_0/clk_out2]
set aresetn [get_bd_pins reset/peripheral_aresetn]
set aresetn_spi [get_bd_pins reset_spi/peripheral_aresetn]
set cfg_data [get_bd_pins hub/cfg_data]
# Clocks
connect_bd_net [get_bd_ports adc_clk_p_i] [get_bd_pins clk_wiz_0/clk_in1_p]
connect_bd_net [get_bd_ports adc_clk_n_i] [get_bd_pins clk_wiz_0/clk_in1_n]
# Reset
connect_bd_net $ref_clk [get_bd_pins reset/slowest_sync_clk]
connect_bd_net $spi_clk [get_bd_pins reset_spi/slowest_sync_clk]
set_property name spi_clk [get_bd_nets -of $spi_clk]
connect_bd_net [get_bd_pins VCC_0/dout] [get_bd_pins reset/ext_reset_in]
connect_bd_net [get_bd_pins VCC_0/dout] [get_bd_pins reset_spi/ext_reset_in]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins reset/dcm_locked]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins reset_spi/dcm_locked]
# Processing System
connect_bd_net $ref_clk [get_bd_pins ps/M_AXI_GP0_ACLK]
connect_bd_net $ref_clk [get_bd_pins ps/S_AXI_ACP_ACLK]
# ADC
connect_bd_net $spi_clk [get_bd_pins adc/aclk]
connect_bd_net [get_bd_pins adc/spi_sck] [get_bd_ports exp_adc_sck]
connect_bd_net [get_bd_ports exp_adc_csn] [get_bd_pins adc/spi_csn]
connect_bd_net [get_bd_pins adc/spi_sdi] [get_bd_ports exp_adc_sdi]
connect_bd_net [get_bd_pins adc/spi_sdo] [get_bd_ports exp_adc_sdo]
connect_bd_net [get_bd_pins adc/spi_resetn] [get_bd_ports exp_adc_resetn]
# AXIS clock converters
connect_bd_intf_net [get_bd_intf_pins clk_converter_in/M_AXIS] [get_bd_intf_pins adc/s_axis]
connect_bd_intf_net [get_bd_intf_pins adc/m_axis] [get_bd_intf_pins clk_converter_out/S_AXIS]
connect_bd_net $spi_clk [get_bd_pins clk_converter_in/m_axis_aclk]
connect_bd_net $ref_clk [get_bd_pins clk_converter_in/s_axis_aclk]
connect_bd_net $ref_clk [get_bd_pins clk_converter_out/m_axis_aclk]
connect_bd_net $spi_clk [get_bd_pins clk_converter_out/s_axis_aclk]
connect_bd_net $aresetn_spi [get_bd_pins clk_converter_in/m_axis_aresetn]
connect_bd_net $aresetn [get_bd_pins clk_converter_in/s_axis_aresetn]
connect_bd_net $aresetn [get_bd_pins clk_converter_out/m_axis_aresetn]
connect_bd_net $aresetn_spi [get_bd_pins clk_converter_out/s_axis_aresetn]
# AXIS packetizer and DMA
connect_bd_intf_net [get_bd_intf_pins clk_converter_out/M_AXIS] [get_bd_intf_pins packetizer/s_axis]
connect_bd_intf_net [get_bd_intf_pins packetizer/m_axis] [get_bd_intf_pins dma/s_axis]
connect_bd_intf_net [get_bd_intf_pins dma/m_axi] [get_bd_intf_pins ps/S_AXI_ACP]
connect_bd_net $ref_clk [get_bd_pins dma/aclk]
connect_bd_net $ref_clk [get_bd_pins packetizer/aclk]
# Hub
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_GP0] [get_bd_intf_pins hub/s_axi]
connect_bd_intf_net [get_bd_intf_pins hub/m00_axis] [get_bd_intf_pins clk_converter_in/S_AXIS]
connect_bd_net $ref_clk [get_bd_pins hub/aclk]
connect_bd_net $aresetn [get_bd_pins hub/aresetn]
# Registers
connect_bd_net $cfg_data [get_bd_pins reset_adc/din]
connect_bd_net $cfg_data [get_bd_pins addr_dma/din]
connect_bd_net $cfg_data [get_bd_pins reset_dma/din]
connect_bd_net $cfg_data [get_bd_pins reset_packetizer/din]
connect_bd_net $cfg_data [get_bd_pins pwr_en/din]
connect_bd_net $cfg_data [get_bd_pins ref_en/din]
connect_bd_net $cfg_data [get_bd_pins io_en/din]
connect_bd_net $cfg_data [get_bd_pins diffamp_en/din]
connect_bd_net $cfg_data [get_bd_pins opamp_en/din]
connect_bd_net [get_bd_pins reset_adc/dout] [get_bd_pins adc/aresetn]
connect_bd_net [get_bd_pins cfg_dma/dout] [get_bd_pins dma/cfg_data]
connect_bd_net [get_bd_pins addr_dma/dout] [get_bd_pins dma/min_addr]
connect_bd_net [get_bd_pins reset_dma/dout] [get_bd_pins dma/aresetn]
connect_bd_net [get_bd_pins reset_packetizer/dout] [get_bd_pins packetizer/aresetn]
connect_bd_net [get_bd_pins cfg_packetizer/dout] [get_bd_pins packetizer/cfg_data]
connect_bd_net [get_bd_pins ref_en/dout] [get_bd_ports exp_adc_ref_en_o]
connect_bd_net [get_bd_pins io_en/dout] [get_bd_ports exp_adc_io_en_o]
connect_bd_net [get_bd_pins pwr_en/dout] [get_bd_ports exp_adc_pwr_en_o]
connect_bd_net [get_bd_pins diffamp_en/dout] [get_bd_ports exp_adc_diffamp_en_o]
connect_bd_net [get_bd_pins opamp_en/dout] [get_bd_ports exp_adc_opamp_en_o]

regenerate_bd_layout
