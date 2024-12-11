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
create_bd_port -dir O exp_adc_ref_en
create_bd_port -dir O exp_adc_io_en
create_bd_port -dir O exp_adc_pwr_en
create_bd_port -dir O exp_adc_diffamp_en
create_bd_port -dir O exp_adc_opamp_en
# Debug pin
create_bd_port -dir O exp_adc_debug
# External clock (on Red Pitaya)
create_bd_port -dir I adc_clk_p_i
create_bd_port -dir I adc_clk_n_i
# LEDs
create_bd_port -dir O -from 0 -to 7 led_o


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

# ADC Config
create_bd_cell -type module -reference axi_exp_adc_cfg adc_cfg

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

# Config registers
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 reset_adc
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells reset_adc]
set_property CONFIG.DIN_FROM {0} [get_bd_cells reset_adc]
set_property CONFIG.DIN_TO {0} [get_bd_cells reset_adc]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 reset_adc_logic
set_property CONFIG.C_SIZE {1} [get_bd_cells reset_adc_logic]
set_property CONFIG.C_OPERATION {and} [get_bd_cells reset_adc_logic]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 reset_packetizer
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells reset_packetizer]
set_property CONFIG.DIN_FROM {1} [get_bd_cells reset_packetizer]
set_property CONFIG.DIN_TO {1} [get_bd_cells reset_packetizer]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 reset_dma
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells reset_dma]
set_property CONFIG.DIN_FROM {2} [get_bd_cells reset_dma]
set_property CONFIG.DIN_TO {2} [get_bd_cells reset_dma]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 ref_en
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells ref_en]
set_property CONFIG.DIN_FROM {3} [get_bd_cells ref_en]
set_property CONFIG.DIN_TO {3} [get_bd_cells ref_en]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 pwr_en
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells pwr_en]
set_property CONFIG.DIN_FROM {4} [get_bd_cells pwr_en]
set_property CONFIG.DIN_TO {4} [get_bd_cells pwr_en]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 io_en
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells io_en]
set_property CONFIG.DIN_FROM {5} [get_bd_cells io_en]
set_property CONFIG.DIN_TO {5} [get_bd_cells io_en]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 diffamp_en
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells diffamp_en]
set_property CONFIG.DIN_FROM {6} [get_bd_cells diffamp_en]
set_property CONFIG.DIN_TO {6} [get_bd_cells diffamp_en]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 opamp_en
set_property CONFIG.DIN_WIDTH {32} [get_bd_cells opamp_en]
set_property CONFIG.DIN_FROM {7} [get_bd_cells opamp_en]
set_property CONFIG.DIN_TO {7} [get_bd_cells opamp_en]

create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 cfg_dma
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

# Fifo r/w counts
#create_bd_cell -type ip -vlnv pavel-demin:user:axis_fifo:1.0 adc_w_fifo
#create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 concat_fifo_status
#set_property -dict [list \
  #CONFIG.IN0_WIDTH {16} \
  #CONFIG.IN1_WIDTH {16} \
#] [get_bd_cells concat_fifo_status]

# LED driver
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 led_concat
set_property CONFIG.NUM_PORTS {8} [get_bd_cells led_concat]

# Connections
set ref_clk [get_bd_pins clk_wiz_0/clk_out1]
set spi_clk [get_bd_pins clk_wiz_0/clk_out2]
set aresetn [get_bd_pins reset/peripheral_aresetn]
set aresetn_spi [get_bd_pins reset_adc_logic/Res]
set cfg_data [get_bd_pins adc_cfg/cfg]
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
# Fifo
#connect_bd_intf_net [get_bd_intf_pins adc_w_fifo/m_axis] [get_bd_intf_pins clk_converter_in/S_AXIS]
#connect_bd_net $aresetn [get_bd_pins adc_w_fifo/aresetn]
#connect_bd_net $ref_clk [get_bd_pins adc_w_fifo/aclk]
#connect_bd_net [get_bd_pins adc_w_fifo/write_count] [get_bd_pins concat_fifo_status/In0]
#connect_bd_net [get_bd_pins adc_w_fifo/read_count] [get_bd_pins concat_fifo_status/In1]
#connect_bd_net [get_bd_pins concat_fifo_status/dout] [get_bd_pins adc_cfg/status]
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
# ADC Config
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
    Clk_master {$ref_clk}
    Clk_slave {$ref_clk}
    Clk_xbar {$ref_clk}
    Master {/ps/M_AXI_GP0}
    Slave {/adc_cfg/s_axi}
    ddr_seg {Auto}
    intc_ip {New AXI SmartConnect} master_apm {0}
} [get_bd_intf_pins adc_cfg/s_axi]

connect_bd_intf_net [get_bd_intf_pins adc_cfg/m_axis] [get_bd_intf_pins clk_converter_in/S_AXIS]
connect_bd_net [get_bd_pins adc_cfg/dma_cfg] [get_bd_pins dma/min_addr]
connect_bd_net [get_bd_pins adc_cfg/packetizer_cfg] [get_bd_pins packetizer/cfg_data]
connect_bd_net [get_bd_pins adc_cfg/trigger] [get_bd_pins adc/trigger]
connect_bd_net $spi_clk [get_bd_pins adc_cfg/adc_clk]
connect_bd_net $aresetn_spi [get_bd_pins adc_cfg/adc_resetn]
# Registers
connect_bd_net [get_bd_pins cfg_dma/dout] [get_bd_pins dma/cfg_data]
connect_bd_net $cfg_data [get_bd_pins reset_adc/din]
connect_bd_net $cfg_data [get_bd_pins reset_dma/din]
connect_bd_net $cfg_data [get_bd_pins reset_packetizer/din]
connect_bd_net $cfg_data [get_bd_pins pwr_en/din]
connect_bd_net $cfg_data [get_bd_pins ref_en/din]
connect_bd_net $cfg_data [get_bd_pins io_en/din]
connect_bd_net $cfg_data [get_bd_pins diffamp_en/din]
connect_bd_net $cfg_data [get_bd_pins opamp_en/din]
connect_bd_net [get_bd_pins reset_adc/dout] [get_bd_pins reset_adc_logic/Op1]
connect_bd_net [get_bd_pins reset_spi/peripheral_aresetn] [get_bd_pins reset_adc_logic/Op2]
connect_bd_net [get_bd_pins reset_adc_logic/Res] [get_bd_pins adc/aresetn]
connect_bd_net [get_bd_pins reset_dma/dout] [get_bd_pins dma/aresetn]
connect_bd_net [get_bd_pins reset_packetizer/dout] [get_bd_pins packetizer/aresetn]
connect_bd_net [get_bd_pins pwr_en/dout] [get_bd_ports exp_adc_pwr_en]
connect_bd_net [get_bd_pins ref_en/dout] [get_bd_ports exp_adc_ref_en]
connect_bd_net [get_bd_pins io_en/dout] [get_bd_ports exp_adc_io_en]
connect_bd_net [get_bd_pins diffamp_en/dout] [get_bd_ports exp_adc_diffamp_en]
connect_bd_net [get_bd_pins opamp_en/dout] [get_bd_ports exp_adc_opamp_en]
# LEDs
connect_bd_net [get_bd_pins led_concat/dout] [get_bd_ports led_o]
connect_bd_net $aresetn [get_bd_pins led_concat/In0]
connect_bd_net [get_bd_pins adc_cfg/trigger] [get_bd_pins led_concat/In1]
connect_bd_net [get_bd_pins adc/spi_resetn] [get_bd_pins led_concat/In2]
connect_bd_net [get_bd_pins pwr_en/dout] [get_bd_pins led_concat/In3]
connect_bd_net [get_bd_pins ref_en/dout] [get_bd_pins led_concat/In4]
connect_bd_net [get_bd_pins io_en/dout] [get_bd_pins led_concat/In5]
connect_bd_net [get_bd_pins diffamp_en/dout] [get_bd_pins led_concat/In6]
connect_bd_net [get_bd_pins opamp_en/dout] [get_bd_pins led_concat/In7]
# Debug
connect_bd_net [get_bd_pins adc_cfg/debug] [get_bd_ports exp_adc_debug]
regenerate_bd_layout
