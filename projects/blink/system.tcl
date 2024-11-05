add_files -norecurse library/blink/blink.v

# create_fileset -simset sim_1
add_files -fileset sim_1 -norecurse library/blink/blink_tb.sv

set_property top blink [current_fileset]

update_compile_order -fileset sources_1

source projects/blink/bd_blink.tcl

validate_bd_design

synth_design -top blink -part $part -lint
