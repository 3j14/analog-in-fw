# Usage: system_project.tcl <name> <part> <out_dir>

set name [lindex $argv 0]
set part [lindex $argv 1]
set path [lindex $argv 2]

create_project -part $part $name $path 
