add_files -norecurse library/spi/axis_exp_adc.v
add_files -fileset sim_1 -norecurse library/spi/axis_exp_adc_tb.sv

# Ignore truncation of AXI Stream register to 24 bits
create_waiver -type LINT -id ASSIGN-10 -rtl_name {s_axis_tdata} -rtl_hierarchy {axis_exp_adc} -rtl_file {axis_exp_adc.v} -description {Ignore truncation of AXI Stream}

set_property IP_REPO_PATHS library/red-pitaya-notes/tmp/cores [current_project]
update_ip_catalog

set_property top axis_exp_adc [current_fileset]
update_compile_order -fileset sources_1

source projects/adc/bd_adc.tcl
