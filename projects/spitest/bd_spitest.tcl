source $ad_hdl_dir/library/spi_engine/scripts/spi_engine.tcl

create_bd_design bd_spitest

create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIMITIVE PLL \
    CONFIG.PRIM_IN_FREQ {125.0} \
    CONFIG.PRIM_SOURCE Differential_clock_capable_pin \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.0} \
    CONFIG.USE_RESET {false} \
] [get_bd_cells /clk_wiz_0]

create_bd_port -dir I adc_clk_p_i
create_bd_port -dir I adc_clk_n_i

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps_0

connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins ps_0/M_AXI_GP0_ACLK]

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
  make_external {FIXED_IO, DDR}
  Master "Disable"
  Slave "Disable"
} [get_bd_cells ps_0]


set sampling_rate 1000000
set num_sdi 4

create_bd_port -dir O adc_spi_clk
create_bd_port -dir O adc_spi_cs
create_bd_port -dir O adc_spi_rst
create_bd_port -dir O adc_spi_sdo

create_bd_port -dir I -from [expr $num_sdi-1] -to 0 adc_spi_sdi

create_bd_port -dir I adc_spi_busy
create_bd_port -dir O adc_spi_cnv

spi_engine_create "adc_spi" 32 1 1 $num_sdi 1 0 0

