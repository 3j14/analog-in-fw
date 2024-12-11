set name [lindex $argv 0]
open_project build/projects/$name/$name.xpr

reset_run impl_1
launch_runs impl_1 -jobs 6
wait_on_run impl_1

