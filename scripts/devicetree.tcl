# Create device tree sources
#
# About:
#   This TCL script is designed to be run using XSCT and uses Xilinx's
#   HSI. As compared to using Vitis Unified IDE, this builds a device tree
#   instead of a system device tree (SDT). Reason for this being that the
#   memory map for system device trees is not compatible with Linux, causing
#   an early kernel panic. The register range for the memory on the Red
#   Pitaya should be set from 0x0 to 0x2000000, whereas the SDT sets three
#   different register ranges for ram_0, ram_1 and ddr_0.
#
#   Usage:
#   
#       xsct scripts/devicetree.tcl <project_name> <processor> <dt_version>
#
#   Example:
#
#       xsct scripts/devicetree.tcl adc ps7_cortexa9_0 2024.2
#
# License:
#   Adapted from Pavel Demin's 'red-pitaya-notes' project, licensed
#   under the MIT License.
#   This project is licensed under the "BSD-3-Clause License".
#

set name [lindex $argv 0]
set processor [lindex $argv 1]
set version [lindex $argv 2]

set build_dir build/projects/$name
set repo_path build/device-tree-xlnx

hsi open_hw_design $build_dir/$name.xsa
hsi set_repo_path $repo_path
hsi create_sw_design device-tree -os device_tree -proc $processor
hsi set_property CONFIG.kernel_version $version [hsi get_os]
hsi set_property CONFIG.dt_overlay {true} [hsi get_os]

hsi generate_target -dir $build_dir/dts
hsi close_hw_design [hsi current_hw_design]
