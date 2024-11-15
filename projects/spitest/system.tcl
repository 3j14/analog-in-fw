source scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

# Add the Analog Devices HDL IP repository
set_property ip_repo_paths $ad_hdl_dir/library [current_project]
update_ip_catalog

# add_files -norecurse $ad_hdl_dir/library/common/ad_iobuf.v
# add_files -norecurse $ad_hdl_dir/library/xilinx/common/ad_data_clk.v

source projects/spitest/bd_spitest.tcl

