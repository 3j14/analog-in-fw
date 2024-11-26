set name [lindex $argv 0]
open_project build/projects/$name/$name.xpr

open_run impl_1
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
write_bitstream -force -file build/projects/$name/$name.bit

