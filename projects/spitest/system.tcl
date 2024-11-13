source scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

# Add the Analog Devices HDL IP repository
set_property ip_repo_paths $ad_hdl_dir/library [current_project]
update_ip_catalog

add_files -norecurse $ad_hdl_dir/library/common/ad_iobuf.v
add_files -norecurse $ad_hdl_dir/library/xilinx/common/ad_data_clk.v

source projects/spitest/bd_spitest.tcl

generate_target all [get_files bd_$name.bd]
make_wrapper -files [get_files bd_$name.bd] -top
add_files -norecurse build/projects/$name/$name.gen/sources_1/bd/bd_$name/hdl/bd_$name_wrapper.v
set_property top bd_$name_wrapper [current_fileset]
update_compile_order -fileset sources_1

