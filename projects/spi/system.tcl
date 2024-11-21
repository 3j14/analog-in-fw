add_files -norecurse library/spi/axis_exp_adc.v
add_files -fileset sim_1 -norecurse library/spi/axis_exp_adc_tb.sv

set_property IP_REPO_PATHS library/pavel-red-pitaya-notes/tmp/cores [current_project]

set_property top axis_exp_adcx [current_fileset]
update_compile_order -fileset sources_1

source projects/adc_test/bd_adc_test.tcl
