add_files -norecurse library/blink/blink.v

# create_fileset -simset sim_1
add_files -fileset sim_1 -norecurse library/blink/blink_tb.sv

set_property top blink [current_fileset]

update_compile_order -fileset sources_1

source projects/blink/bd_blink.tcl

generate_target all [get_files bd_blink.bd]
make_wrapper -files [get_files bd_blink.bd] -top
add_files -norecurse build/projects/blink/blink.gen/sources_1/bd/bd_blink/hdl/bd_blink_wrapper.v
set_property top bd_blink_wrapper [current_fileset]
update_compile_order -fileset sources_1

#synth_design -top blink -part $part -lint
