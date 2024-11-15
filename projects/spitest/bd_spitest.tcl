source $ad_hdl_dir/library/spi_engine/scripts/spi_engine.tcl

set adc_clk_in_freq 125.0
set ref_clk_freq 125.0
set spi_clk_freq 100.0
set sampling_rate 1.0
set num_sdi 4
set n_cycles [expr int(ceil(double($ref_clk_freq) / double($sampling_rate)))]

create_bd_design bd_spitest

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
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $spi_clk_freq \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_LOCKED {false}
] [get_bd_cells clk_wiz_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset reset
# Create PWM clock from 125 MHz clock
# Clock 1: Used to trigger the conversion, directly routed to the
#   CNV pin on the expansion port.
# Clock 2: Triggers the SPI acquisition using the offload IP
create_bd_cell -type ip -vlnv analog.com:user:axi_pwm_gen:1.0 cnv_gen
set_property -dict [list \
    CONFIG.N_PWMS 2 \
    CONFIG.PULSE_0_PERIOD $n_cycles \
    CONFIG.PULSE_0_WIDTH 1 \
    CONFIG.PULSE_1_PERIOD $n_cycles \
    CONFIG.PULSE_1_WIDTH 1 \
    CONFIG.PULSE_1_OFFSET [expr $n_cycles + 1]
] [get_bd_cells cnv_gen]

# Processing system
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps
set_property \
    CONFIG.PCW_IMPORT_BOARD_PRESET "library/pavel-red-pitaya-notes/cfg/red_pitaya.xml" \
    [get_bd_cells ps]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
make_external {FIXED_IO, DDR}
  Master "Disable"
  Slave "Disable"
} [get_bd_cells ps]
set_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} [get_bd_cells ps]
set_property CONFIG.PCW_EN_CLK0_PORT {1} [get_bd_cells ps]

# Create AXI interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect
set_property CONFIG.NUM_MI {3} [get_bd_cells axi_interconnect]

spi_engine_create "adc_spi" 32 1 1 $num_sdi 1 0 0

# Configure for capture zone 2:
# The data of sample N is read at the beginning of conversion N + 1.
# Set the trigger to be asynchronous, so we can trigger the acquisition
# any time.
set_property CONFIG.ASYNC_TRIG {true} [get_bd_cells adc_spi/adc_spi_offload]

# ADC DMA
create_bd_cell -type ip -vlnv analog.com:user:spi_axis_reorder:1.0 data_reorderer
set_property CONFIG.NUM_OF_LANES {4} [get_bd_cells data_reorderer]
create_bd_cell -type ip -vlnv analog.com:user:axi_dmac:1.0 adc_axi_dma
set_property CONFIG.DMA_TYPE_SRC {1} [get_bd_cells adc_axi_dma]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_hp2_interconnect
set_property CONFIG.NUM_MI {1} [get_bd_cells axi_hp2_interconnect]
set_property CONFIG.PCW_USE_S_AXI_HP2 {1} [get_bd_cells ps]

set axi_aclk [get_bd_pins ps/FCLK_CLK0]
set axi_aresetn [get_bd_pins reset/peripheral_aresetn]
set ref_clk [get_bd_pins clk_wiz_0/clk_out1]
set spi_clk [get_bd_pins clk_wiz_0/clk_out2]
set vcc [get_bd_pins VCC_0/dout]
set gnd [get_bd_pins GND_0/dout]
# Connections
# Clocks
connect_bd_net [get_bd_ports adc_clk_p_i] [get_bd_pins clk_wiz_0/clk_in1_p]
connect_bd_net [get_bd_ports adc_clk_n_i] [get_bd_pins clk_wiz_0/clk_in1_n]
# connect_bd_net [get_bd_pins reset/dcm_locked] [get_bd_pins clk_wiz_0/locked]
connect_bd_net $axi_aclk [get_bd_pins reset/slowest_sync_clk]
connect_bd_net [get_bd_pins ps/FCLK_RESET0_N] [get_bd_pins reset/ext_reset_in]
# AXI interconnect
connect_bd_net $axi_aclk [get_bd_pins ps/M_AXI_GP0_ACLK]
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_GP0] [get_bd_intf_pins axi_interconnect/S00_AXI]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect/ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect/S00_ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect/M00_ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect/M01_ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect/M02_ACLK]
connect_bd_net $axi_aresetn [get_bd_pins axi_interconnect/ARESETN]
connect_bd_net $axi_aresetn [get_bd_pins axi_interconnect/S00_ARESETN]
connect_bd_net $axi_aresetn [get_bd_pins axi_interconnect/M00_ARESETN]
connect_bd_net $axi_aresetn [get_bd_pins axi_interconnect/M01_ARESETN]
connect_bd_net $axi_aresetn [get_bd_pins axi_interconnect/M02_ARESETN]
# ADC data reorderer
connect_bd_net $vcc [get_bd_pins data_reorderer/axis_aresetn]
connect_bd_net $spi_clk [get_bd_pins data_reorderer/axis_aclk]
connect_bd_intf_net [get_bd_intf_pins adc_spi/m_axis_sample] [get_bd_intf_pins data_reorderer/s_axis]
# ADC DMA
connect_bd_intf_net [get_bd_intf_pins data_reorderer/m_axis] [get_bd_intf_pins adc_axi_dma/s_axis]
connect_bd_net $spi_clk [get_bd_pins adc_axi_dma/s_axis_aclk]
connect_bd_net $axi_aclk [get_bd_pins adc_axi_dma/s_axi_aclk]
connect_bd_net $axi_aclk [get_bd_pins adc_axi_dma/m_dest_axi_aclk]
connect_bd_net $axi_aresetn [get_bd_pins adc_axi_dma/s_axi_aresetn]
connect_bd_net $axi_aresetn [get_bd_pins adc_axi_dma/m_dest_axi_aresetn]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect/M02_AXI] [get_bd_intf_pins adc_axi_dma/s_axi]
# AXI HP2 Interconnect
connect_bd_intf_net [get_bd_intf_pins adc_axi_dma/m_dest_axi] -boundary_type upper [get_bd_intf_pins axi_hp2_interconnect/S00_AXI]
connect_bd_net $axi_aresetn [get_bd_pins axi_hp2_interconnect/ARESETN]
connect_bd_net $axi_aresetn [get_bd_pins axi_hp2_interconnect/S00_ARESETN]
connect_bd_net $axi_aresetn [get_bd_pins axi_hp2_interconnect/M00_ARESETN]
connect_bd_net $axi_aclk [get_bd_pins axi_hp2_interconnect/ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_hp2_interconnect/S00_ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_hp2_interconnect/M00_ACLK]
connect_bd_intf_net [get_bd_intf_pins ps/S_AXI_HP2] [get_bd_intf_pins axi_hp2_interconnect/M00_AXI]
connect_bd_net $axi_aclk [get_bd_pins ps/S_AXI_HP2_ACLK]
# ADC CNV gen
connect_bd_intf_net [get_bd_intf_pins axi_interconnect/M01_AXI] [get_bd_intf_pins cnv_gen/s_axi]
connect_bd_net $axi_aresetn [get_bd_pins cnv_gen/s_axi_aresetn]
connect_bd_net $ref_clk [get_bd_pins cnv_gen/ext_clk]
connect_bd_net [get_bd_pins cnv_gen/pwm_0] [get_bd_pins exp_adc_cnv]
connect_bd_net $axi_aclk [get_bd_pins cnv_gen/s_axi_aclk]
# ADC
connect_bd_intf_net [get_bd_intf_pins axi_interconnect/M00_AXI] [get_bd_intf_pins adc_spi/adc_spi_axi_regmap/s_axi]
connect_bd_net [get_bd_pins cnv_gen/pwm_1] [get_bd_pins adc_spi/trigger]
connect_bd_net [get_bd_ports exp_adc_sdo] [get_bd_pins adc_spi/adc_spi_execution/sdo]
connect_bd_net [get_bd_ports exp_adc_sdi] [get_bd_pins adc_spi/adc_spi_execution/sdi]
connect_bd_net [get_bd_ports exp_adc_sck] [get_bd_pins adc_spi/adc_spi_execution/sclk]
connect_bd_net [get_bd_ports exp_adc_csn] [get_bd_pins adc_spi/adc_spi_execution/cs]
connect_bd_net $axi_aresetn [get_bd_pins adc_spi/resetn]
connect_bd_net $axi_aclk [get_bd_pins adc_spi/clk]
connect_bd_net $spi_clk [get_bd_pins adc_spi/spi_clk]

regenerate_bd_layout

assign_bd_address \
    -target_address_space [get_bd_addr_spaces adc_axi_dma/m_dest_axi] \
    [get_bd_addr_segs ps/S_AXI_HP2/HP2_DDR_LOWOCM] \
    -force
set_property \
    offset 0x0 \
    [get_bd_addr_segs {adc_axi_dma/m_dest_axi/SEG_ps_HP2_DDR_LOWOCM}]
set_property \
    range 512M \
    [get_bd_addr_segs {adc_axi_dma/m_dest_axi/SEG_ps_HP2_DDR_LOWOCM}]

# DMA
set ps_data_adr_space [get_bd_addr_spaces /ps/Data]
assign_bd_address \
    -target_address_space $ps_data_adr_space \
    [get_bd_addr_segs adc_axi_dma/s_axi/axi_lite] \
    -force
set_property offset 0x44A30000 [get_bd_addr_segs {ps/Data/SEG_adc_axi_dma_axi_lite}]
set_property range 4K [get_bd_addr_segs ps/Data/SEG_adc_axi_dma_axi_lite]
# ADC Reg map
assign_bd_address \
    -target_address_space $ps_data_adr_space \
    [get_bd_addr_segs adc_spi/adc_spi_axi_regmap/s_axi/axi_lite] \
    -force
set_property range 64K [get_bd_addr_segs ps/Data/SEG_adc_spi_axi_regmap_axi_lite]
set_property offset 0x44A00000 [get_bd_addr_segs ps/Data/SEG_adc_spi_axi_regmap_axi_lite]
# CNV Gen
assign_bd_address \
    -target_address_space $ps_data_adr_space \
    [get_bd_addr_segs cnv_gen/s_axi/axi_lite] \
    -force
set_property offset 0x44B00000 [get_bd_addr_segs ps/Data/SEG_cnv_gen_axi_lite]
set_property range 64K [get_bd_addr_segs ps/Data/SEG_cnv_gen_axi_lite]

