add_files -norecurse library/blink/blink.sv

# create_fileset -simset sim_1
add_files -fileset sim_1 -norecurse library/blink/blink_tb.sv

set_property top blink [current_fileset]
synth_design -top blink -part $part -lint
