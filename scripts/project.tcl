# Usage: project.tcl <name> <part> <out_dir>

set name [lindex $argv 0]
set part [lindex $argv 1]
set path [lindex $argv 2]

create_project -part $part $name $path
source ./projects/$name/system.tcl

# create_fileset -constrset constrs_1
add_files -fileset constrs_1 -norecurse constraints/redpitaya.xdc

