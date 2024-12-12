add_files -norecurse library/spi/axis4lite_helpers.v
add_files -norecurse library/spi/adc_manager.v
add_files -norecurse library/spi/adc_config.v
add_files -norecurse library/spi/adc_trigger.v
add_files -fileset sim_1 -norecurse library/spi/adc_manager_tb.sv
add_files -fileset sim_1 -norecurse library/spi/adc_trigger_tb.sv

# Ignore truncation of AXI Stream register to 24 bits
create_waiver -type LINT -id ASSIGN-10 -rtl_name {s_axis_tdata} -rtl_hierarchy {adc_manager} -rtl_file {adc_manager.v} -description {Ignore truncation of AXI Stream}

set_property top adc_manager [current_fileset]
update_compile_order -fileset sources_1
source projects/adc/bd_adc.tcl

assign_bd_address -target_address_space /ps/Data [get_bd_addr_segs adc_cfg/s_axi/reg0] -force
set_property range 512 [get_bd_addr_segs {ps/Data/SEG_adc_cfg_reg0}]

