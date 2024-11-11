set name [lindex $argv 0]
open_project build/projects/$name/$name.xpr

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
