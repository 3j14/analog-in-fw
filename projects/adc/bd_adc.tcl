create_bd_design bd_${name}

set adc_clk_in_freq 125.0
set ref_clk_freq 125.0
set adc_clk_freq 50.0
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
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $adc_clk_freq \
    CONFIG.CLKOUT2_REQUESTED_DUTY_CYCLE {25} \
    CONFIG.CLKOUT2_SEQUENCE_NUMBER {1} \
    CONFIG.CLKOUT2_DRIVES {BUFGCE} \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
    CONFIG.USE_CLOCK_SEQUENCING {true} \
] [get_bd_cells clk_wiz_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset reset_adc

# Processing system
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps
set_property -dict [list \
    CONFIG.PCW_IMPORT_BOARD_PRESET "library/red-pitaya-notes/cfg/red_pitaya.xml" \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
] [get_bd_cells ps]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
make_external {FIXED_IO, DDR}
    Master "Disable"
    Slave "Disable"
} [get_bd_cells ps]

# ADC manager, config, trigger and packetizer
create_bd_cell -type module -reference adc_manager adc_manager
create_bd_cell -type module -reference adc_config adc_config
create_bd_cell -type module -reference adc_trigger adc_trigger
create_bd_cell -type module -reference packetizer packetizer

# DMA
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma
set_property -dict [list \
  CONFIG.c_include_mm2s {0} \
  CONFIG.c_include_s2mm_dre {0} \
  CONFIG.c_include_sg {0} \
  CONFIG.c_s2mm_burst_size {128} \
] [get_bd_cells axi_dma]

# LED driver
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 led_concat
set_property CONFIG.NUM_PORTS {8} [get_bd_cells led_concat]

# Connections
set ref_clk [get_bd_pins clk_wiz_0/clk_out1]
set adc_clk [get_bd_pins clk_wiz_0/clk_out2]
set aresetn [get_bd_pins reset/peripheral_aresetn]
set aresetn_adc [get_bd_pins reset_adc/peripheral_aresetn]
set cfg_data [get_bd_pins adc_cfg/cfg]
# Clocks
connect_bd_net [get_bd_ports adc_clk_p_i] [get_bd_pins clk_wiz_0/clk_in1_p]
connect_bd_net [get_bd_ports adc_clk_n_i] [get_bd_pins clk_wiz_0/clk_in1_n]
# Reset
connect_bd_net $ref_clk [get_bd_pins reset/slowest_sync_clk]
connect_bd_net $adc_clk [get_bd_pins reset_adc/slowest_sync_clk]
set_property name adc_clk [get_bd_nets -of $adc_clk]
connect_bd_net [get_bd_pins VCC_0/dout] [get_bd_pins reset/ext_reset_in]
connect_bd_net [get_bd_pins VCC_0/dout] [get_bd_pins reset_adc/ext_reset_in]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins reset/dcm_locked]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins reset_adc/dcm_locked]
# Processing System
connect_bd_net $ref_clk [get_bd_pins ps/M_AXI_GP0_ACLK]
connect_bd_net $ref_clk [get_bd_pins ps/S_AXI_HP0_ACLK]
# ADC Config
connect_bd_net $adc_clk [get_bd_pins adc_config/aclk]
connect_bd_net $aresetn_adc [get_bd_pins adc_config/aresetn]
# ADC Manager
connect_bd_net $adc_clk [get_bd_pins adc_manager/aclk]
connect_bd_net $aresetn_adc [get_bd_pins adc_manager/aresetn]
connect_bd_intf_net [get_bd_intf_pins adc_config/m_axis] [get_bd_intf_pins adc_manager/s_axis]
connect_bd_net [get_bd_ports exp_adc_sdi] [get_bd_pins adc_manager/spi_sdi]
connect_bd_net [get_bd_ports exp_adc_sdo] [get_bd_pins adc_manager/spi_sdo]
connect_bd_net [get_bd_ports exp_adc_csn] [get_bd_pins adc_manager/spi_csn]
connect_bd_net [get_bd_ports exp_adc_sck] [get_bd_pins adc_manager/spi_sck]
connect_bd_net [get_bd_ports exp_adc_resetn] [get_bd_pins adc_manager/spi_resetn]
connect_bd_net [get_bd_pins adc_manager/status] [get_bd_pins adc_config/status]
# Packetizer
connect_bd_net $adc_clk [get_bd_pins packetizer/aclk]
connect_bd_net $aresetn_adc [get_bd_pins packetizer/aresetn]
connect_bd_intf_net [get_bd_intf_pins adc_manager/m_axis] [get_bd_intf_pins packetizer/s_axis_data]
# ADC Trigger
connect_bd_net $adc_clk [get_bd_pins adc_trigger/aclk]
connect_bd_net $aresetn_adc [get_bd_pins adc_trigger/aresetn]
connect_bd_net [get_bd_pins packetizer/last] [get_bd_pins adc_trigger/last]
connect_bd_net [get_bd_pins adc_trigger/trigger] [get_bd_pins adc_manager/trigger]
connect_bd_net [get_bd_ports exp_adc_cnv] [get_bd_pins adc_trigger/cnv]
connect_bd_net [get_bd_ports exp_adc_busy] [get_bd_pins adc_trigger/busy]
# DMA
connect_bd_intf_net [get_bd_intf_pins packetizer/m_axis_s2mm] [get_bd_intf_pins axi_dma/S_AXIS_S2MM]
connect_bd_net $aresetn_adc [get_bd_pins axi_dma/axi_resetn]
connect_bd_net $adc_clk [get_bd_pins axi_dma/m_axi_s2mm_aclk]
connect_bd_net $adc_clk [get_bd_pins axi_dma/s_axi_lite_aclk]
connect_bd_net [get_bd_pins axi_dma/s2mm_introut] [get_bd_pins ps/IRQ_F2P]
# Automation
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {$ref_clk} Clk_slave {$adc_clk} Clk_xbar {Auto} Master {/ps/M_AXI_GP0} Slave {/adc_config/s_axi_lite} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins adc_config/s_axi_lite]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {$ref_clk} Clk_slave {$adc_clk} Clk_xbar {Auto} Master {/ps/M_AXI_GP0} Slave {/adc_trigger/s_axi_lite} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins adc_trigger/s_axi_lite]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {$ref_clk} Clk_slave {$adc_clk} Clk_xbar {Auto} Master {/ps/M_AXI_GP0} Slave {/axi_dma/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_dma/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {$ref_clk} Clk_slave {$adc_clk} Clk_xbar {Auto} Master {/ps/M_AXI_GP0} Slave {/packetizer/s_axi_lite} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins packetizer/s_axi_lite]
# TODO: Check if using 'AXI SmartConnect' for S_AXI_HP0_ACLK can work
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {$adc_clk} Clk_slave {$ref_clk} Clk_xbar {Auto} Master {/axi_dma/M_AXI_S2MM} Slave {/ps/S_AXI_HP0} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins ps/S_AXI_HP0]
# IO
connect_bd_net [get_bd_ports exp_adc_pwr_en] [get_bd_pins adc_config/pwr_en]
connect_bd_net [get_bd_ports exp_adc_ref_en] [get_bd_pins adc_config/ref_en]
connect_bd_net [get_bd_ports exp_adc_io_en] [get_bd_pins adc_config/io_en]
connect_bd_net [get_bd_ports exp_adc_diffamp_en] [get_bd_pins adc_config/diffamp_en]
connect_bd_net [get_bd_ports exp_adc_opamp_en] [get_bd_pins adc_config/opamp_en]
# LEDs
connect_bd_net [get_bd_pins led_concat/dout] [get_bd_ports led_o]
connect_bd_net [get_bd_pins adc_trigger/cnv] [get_bd_pins led_concat/In0]
connect_bd_net $aresetn_adc [get_bd_pins led_concat/In1]
connect_bd_net [get_bd_pins adc_manager/spi_csn] [get_bd_pins led_concat/In2]
connect_bd_net [get_bd_pins adc_config/pwr_en] [get_bd_pins led_concat/In3]
connect_bd_net [get_bd_pins adc_config/ref_en] [get_bd_pins led_concat/In4]
connect_bd_net [get_bd_pins adc_config/io_en] [get_bd_pins led_concat/In5]
connect_bd_net [get_bd_pins adc_config/diffamp_en] [get_bd_pins led_concat/In6]
connect_bd_net [get_bd_pins adc_config/opamp_en] [get_bd_pins led_concat/In7]

regenerate_bd_layout
