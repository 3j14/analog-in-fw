add_files -norecurse library/spi/axis_exp_adc.v
add_files -fileset sim_1 -norecurse library/spi/axis_exp_adc_tb.sv

set_property IP_REPO_PATHS library/red-pitaya-notes/tmp/cores [current_project]
update_ip_catalog

set_property top axis_exp_adc [current_fileset]
update_compile_order -fileset sources_1

source projects/adc/bd_adc.tcl
