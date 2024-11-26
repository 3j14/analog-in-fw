set name [lindex $argv 0]
open_project build/projects/$name/$name.xpr

write_hw_platform -fixed -force -file build/projects/$name/$name.xsa

