add_files -norecurse library/adc/axi4lite_helpers.vh
add_files -norecurse library/adc/adc_manager.v
add_files -norecurse library/adc/adc_config.v
add_files -norecurse library/adc/adc_trigger.v
add_files -norecurse library/adc/packetizer.v
add_files -norecurse library/misc/delay.v
add_files -fileset sim_1 -norecurse library/adc/adc_manager_tb.sv
add_files -fileset sim_1 -norecurse library/adc/adc_trigger_tb.sv
add_files -fileset sim_1 -norecurse library/adc/packetizer_tb.sv
add_files -fileset sim_1 -norecurse library/misc/delay_tb.sv

# Ignore truncation of AXI Stream register to 24 bits
create_waiver -type LINT -id ASSIGN-10 -rtl_name {s_axis_tdata} -rtl_hierarchy {adc_manager} -rtl_file {adc_manager.v} -description {Ignore truncation of AXI Stream}

set_property top adc_manager [current_fileset]
update_compile_order -fileset sources_1
source projects/adc/bd_adc.tcl

assign_bd_address -target_address_space /ps/Data [get_bd_addr_segs adc_config/s_axi_lite/reg0] -force
set_property range 256 [get_bd_addr_segs {ps/Data/SEG_adc_config_reg0}]
set_property offset 0x40000000 [get_bd_addr_segs {ps/Data/SEG_adc_config_reg0}]

include_bd_addr_seg [get_bd_addr_segs -excluded ps/Data/SEG_adc_trigger_reg0]
assign_bd_address -target_address_space /ps/Data [get_bd_addr_segs adc_trigger/s_axi_lite/reg0] -force
set_property range 256 [get_bd_addr_segs {ps/Data/SEG_adc_trigger_reg0}]
set_property offset 0x40000100 [get_bd_addr_segs {ps/Data/SEG_adc_trigger_reg0}]

include_bd_addr_seg [get_bd_addr_segs -excluded ps/Data/SEG_packetizer_reg0]
assign_bd_address -target_address_space /ps/Data [get_bd_addr_segs packetizer/s_axi_lite/reg0] -force
set_property range 256 [get_bd_addr_segs {ps/Data/SEG_packetizer_reg0}]
set_property offset 0x40000200 [get_bd_addr_segs {ps/Data/SEG_packetizer_reg0}]

include_bd_addr_seg [get_bd_addr_segs -excluded ps/Data/SEG_axi_dma_Reg]
assign_bd_address -target_address_space /ps/Data [get_bd_addr_segs axi_dma/S_AXI_LITE/Reg] -force
set_property range 64K [get_bd_addr_segs {ps/Data/SEG_axi_dma_Reg}]
set_property offset 0x40400000 [get_bd_addr_segs {ps/Data/SEG_axi_dma_Reg}]

