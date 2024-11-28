set name [lindex $argv 0]
set processor [lindex $argv 1]
set version [lindex $argv 2]

set build_dir build/projects/$name
set repo_path build/device-tree-xlnx

hsi open_hw_design $build_dir/$name.xsa
hsi set_repo_path $repo_path
hsi create_sw_design device-tree -os device_tree -proc $processor
hsi set_property CONFIG.kernel_version $version [hsi get_os]

hsi generate_target -dir $build_dir/devicetree
hsi close_hw_design [hsi current_hw_design]
