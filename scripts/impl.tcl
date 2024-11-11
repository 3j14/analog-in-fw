set name [lindex $argv 0]
open_project build/projects/$name/$name.xpr

launch_runs -jobs 10 system_*_synth_1 synth_1
wait_on_run synth_1
open_run synth_1
