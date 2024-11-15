# Usage: project.tcl <name> <part> <out_dir>

set name [lindex $argv 0]
set part [lindex $argv 1]
set path [lindex $argv 2]

create_project -force -part $part $name $path
source ./projects/$name/system.tcl

# create_fileset -constrset constrs_1
add_files -fileset constrs_1 -norecurse constraints/redpitaya.xdc
add_files -fileset constrs_1 -norecurse constraints/clocks.xdc

generate_target all [get_files bd_${name}.bd]
make_wrapper -files [get_files bd_${name}.bd] -top
add_files -norecurse build/projects/${name}/${name}.gen/sources_1/bd/bd_${name}/hdl/bd_${name}_wrapper.v
set_property top bd_${name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

