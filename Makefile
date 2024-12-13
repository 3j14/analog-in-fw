# Makefile for 'analog-in-fw'
#
# Build the FPGA projects, Linux, the device tree, bootloader, and
# Debian based SD card image.
#
#
# Usage:
#	Specify the name of the project using the 'PROJECT' variable:
#
#		make PROJECT=blink
#
#	Targets:
#		- image: SD card image
#		- software: Software part of the projects (binary executable)
#		- dtbo: Device tree overlay file
#		- dtb: Device tree for rootfs image
#		- boot: boot.bin file
#		- linux: Build the Linux kernel
#		- fsbl: First-stage bootloader (requires Vitis Unified IDE)
#		- ssbl: Second-stage bootloader by Pavel Demin, replaces U-Boot
#		- xsa: Xilinx support archive used for device tree and FSBL.
#		- bitstream: FPGA bitstream
#		- impl: Vivado FPGA implementation
#		- project: Vivado FPGA project
#
# License:
#	Some targets are adapted from Pavel Demin's 'red-pitaya-notes'
#	project, licensed under the MIT License.
#	This project is licensed under the "BSD-3-Clause License".
#
SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

PROJECT ?= adc
PART ?= xc7z010clg400-1
PROCESSOR ?= ps7_cortexa9_0

# Executables
VIVADO = vivado
XSCT = xsct
VITIS = vitis
VIVADO_MODE ?= batch
VIVADO_ARGS ?= -mode $(VIVADO_MODE) -log build/vivado.log -journal build/vivado.jou
_VIVADO := $(VIVADO) $(VIVADO_ARGS)
# Overwrite Analog Devices' Vivado version check
REQUIRED_VIVADO_VERSION ?= 2024.2
export REQUIRED_VIVADO_VERSION

BUILD_DIR = build/projects/$(PROJECT)
PROJECTS = $(notdir $(wildcard ./projects/*))

# Linux, SSBL, and device tree configuration
DEVICE_TREE_VER ?= 2024.2
DEVICE_TREE_TARBALL := https://github.com/Xilinx/device-tree-xlnx/archive/refs/tags/xilinx_v$(DEVICE_TREE_VER).tar.gz
SSBL_VERSION ?= 20231206
SSBL_TARBALL := https://github.com/pavel-demin/ssbl/archive/refs/tags/$(SSBL_VERSION).tar.gz
LINUX_VERSION ?= 6.12
LINUX_TARBALL := https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$(LINUX_VERSION).tar.xz
FPGAUTIL_VERSION ?= 2024.2
FPGAUTIL_C := https://github.com/Xilinx/meta-xilinx/raw/refs/tags/xlnx-rel-v$(FPGAUTIL_VERSION)/meta-xilinx-core/recipes-bsp/fpga-manager-script/files/fpgautil.c

# Targets for Analog Devices' SPI Engine
ADI_HDL_DIR := library/adi-hdl
ADI_HDL_IPS := $(dir $(shell find $(ADI_HDL_DIR)/library/spi_engine -name Makefile))
ADI_HDL_IPS += $(dir $(shell find $(ADI_HDL_DIR)/library/axi_pwm_gen -name Makefile))
ADI_HDL_ALL := $(addsuffix all, $(ADI_HDL_IPS))
ADI_HDL_CLEAN := $(addsuffix clean, $(ADI_HDL_IPS))

# Targets for Pavel Demin's Red Pitaya Notes
RPN_DIR := library/red-pitaya-notes
RPN_CORE_FILES := $(wildcard $(RPN_DIR)/cores/*.v)
RPN_CORES := $(basename $(notdir $(RPN_CORE_FILES)))
RPN_CORES_BUILD_DIRS := $(addprefix $(RPN_DIR)/tmp/cores/,$(RPN_CORES))

HDL_FILES := $(shell find library \( -path $(RPN_DIR) -o -path $(ADI_HDL_DIR) \) -prune -false -o -name \*.v -o -name \*.sv | sort)
HDL_FILES += $(shell find projects -name \*.v -o -name \*.sv | sort)
HDL_INCLUDE_DIRS := $(shell find library \( -path $(RPN_DIR) -o -path $(ADI_HDL_DIR) \) -prune -false -o -name \*.v -o -name \*.sv -exec dirname "{}" \; | sort -u) 
HDL_INCLUDES := $(addprefix -I,$(HDL_INCLUDE_DIRS))

DTS_SOURCES := $(wildcard $(RPN_DIR)/dts/*.dts)
DTS_SOURCES += $(wildcard dts/*.dts)

LINUX_OTHER_SOURCES := linux/linux-$(LINUX_VERSION).patch
LINUX_OTHER_SOURCES := linux/linux-configfs-$(LINUX_VERSION).patch
LINUX_OTHER_SOURCES += linux/xilinx_zynq_defconfig
LINUX_OTHER_SOURCES += linux/configfs.c

SOURCES := $(wildcard library/*/*.v)
SOURCES += $(wildcard library/*/*.sv)
SOURCES += $(wildcard projects/$(PROJECT)/*.v)
SOURCES += $(wildcard projects/$(PROJECT)/*.sv)
SOURCES += $(wildcard projects/$(PROJECT)/*.tcl)
SOURCES += $(wildcard constraints/*.xdc)
SOURCES += $(wildcard constraints/*.tcl)
ifeq ($(PROJECT), spitest)
SOURCES += $(ADI_HDL_ALL)
endif

EXTRA_EXE := $(basename $(addprefix $(BUILD_DIR)/software/,$(notdir $(wildcard projects/$(PROJECT)/software/*.c))))

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	YOSYS_SIM := /usr/share/yosys/xilinx/cells_sim.v
endif
ifeq ($(UNAME_S),Darwin)
	YOSYS_SIM := /opt/homebrew/share/yosys/xilinx/cells_sim.v
endif

define bootbif
// arch = zynq; split = false; format = BIN
img:
{
	[bootloader] build/fsbl.elf $(BUILD_DIR)/$(PROJECT).bit build/ssbl.elf
	[load=0x2000000] build/rootfs.dtb
	[load=0x2008000] build/zImage.bin
}
endef

.PHONY: all image dtb linux fsbl ssbl xsa bitstream impl project clean
all: image bitstream
image: build/red-pitaya-debian-bookworm-armhf.img
software: $(EXTRA_EXE)
boot: build/boot.bin
dtbo: $(BUILD_DIR)/pl.dtbo
dtb: build/rootfs.dtb
linux: build/zImage.bin
fsbl: build/fsbl.elf
ssbl: build/ssbl.elf
xsa: $(BUILD_DIR)/$(PROJECT).xsa
fpgautil: build/fpgautil
bin: $(BUILD_DIR)/$(PROJECT).bin
bitstream: $(BUILD_DIR)/$(PROJECT).bit
impl: $(BUILD_DIR)/$(PROJECT).runs/impl_1
project: $(BUILD_DIR)/$(PROJECT).xpr

clean: $(ADI_HDL_CLEAN)
	$(MAKE) -C $(RPN_DIR) clean
	rm -rf -- build .Xil _ide vivado_*.str

build/red-pitaya-debian-bookworm-armhf.img: build/boot.bin build/zImage.bin build/fpgautil $(EXTRA_EXE) $(BUILD_DIR)/$(PROJECT).bin $(BUILD_DIR)/pl.dtbo
	# Build the Linux image
	# The script may ask you for your password as administrator
	# privileges are required for some operations.
	./scripts/image.sh $(PROJECT) $(LINUX_VERSION) $(EXTRA_EXE)

build/boot.bin: build/rootfs.dtb build/ssbl.elf build/fsbl.elf build/zImage.bin $(BUILD_DIR)/$(PROJECT).bit
	# Generate the boot.bin file using 'bootgen'
	echo "$(bootbif)" > $(@D)/boot.bif
	bootgen -image $(@D)/boot.bif -w -o $@

build/rootfs.dtb: $(BUILD_DIR)/dts/system-top.dts $(DTS_SOURCES)
	# Compile the device trees to a 'dtb'
	dtc -I dts -O dtb -@ -o $@ $(addprefix -i ,$(sort $(^D))) dts/rootfs.dts

$(BUILD_DIR)/dts/system-top.dts: build/device-tree-xlnx $(BUILD_DIR)/$(PROJECT).xsa
	# Prepare the device tree sources using xsct
	mkdir -p $(@D)
	$(XSCT) scripts/devicetree.tcl $(PROJECT) $(PROCESSOR) $(DEVICE_TREE_VER)
	# Use /include/ instead of #include to make the dts files
	# compatible with 'dtc'.
	sed -i 's|#include|/include/|' $@
	sed -i 's|\.bin|$(PROJECT).bin|' $(@D)/pl.dtsi

$(BUILD_DIR)/dts/pl.dtsi: $(BUILD_DIR)/dts/system-top.dts

build/ssbl.elf: build/ssbl-$(SSBL_VERSION)
	# Compile the second-stage bootloader
	$(MAKE) -C $<
	mv $</$(@F) $@

build/ssbl-$(SSBL_VERSION):
	# Download the sources for the second-stage bootloader,
	# a replacement for U-Boot.
	mkdir -p $@
	curl -L --output - $(SSBL_TARBALL) | tar xz --strip-components 1 -C $@
	sed -i 's\arm-none-eabi-gcc\/usr/bin/arm-none-eabi-gcc\' $@/Makefile

.NOTPARALLEL: build/fsbl.elf $(BUILD_DIR)/fsbl/zynq_fsbl
build/fsbl.elf: $(BUILD_DIR)/fsbl/zynq_fsbl
	# Compile the second stage bootloader
	$(VITIS) --source scripts/fsbl.py build $(PROJECT)
	cp $</build/fsbl.elf $@

$(BUILD_DIR)/fsbl/zynq_fsbl: $(BUILD_DIR)/$(PROJECT).xsa $(RPN_DIR)/patches/red_pitaya_fsbl_hooks.c $(RPN_DIR)/patches/fsbl.patch
	# Remove fsbl directory to prevent errors when creating the sources
	rm -rf -- $(@D)
	# Prepare the FSBL sources using the Vitis Unified IDE
	$(VITIS) --source scripts/fsbl.py create $(PROJECT)
	# Apply the MAC address hook for the FSBL
	cp $(RPN_DIR)/patches/red_pitaya_fsbl_hooks.c $@
	patch $@/fsbl_hooks.c $(RPN_DIR)/patches/fsbl.patch
	sed -i 's\XPAR_PS7_ETHERNET_0_DEVICE_ID\0\g' $@/red_pitaya_fsbl_hooks.c
	sed -i 's\XPAR_PS7_I2C_0_DEVICE_ID\0\g' $@/red_pitaya_fsbl_hooks.c
	sed -i '/fsbl_hooks.c)/a collect (PROJECT_LIB_SOURCES red_pitaya_fsbl_hooks.c)' $@/CMakeLists.txt

build/device-tree-xlnx:
	# Download the 'xilinx/device-tree-xlnx' repository
	mkdir -p $@
	curl -L --output - $(DEVICE_TREE_TARBALL) | tar xz --strip-components 1 -C $@

$(BUILD_DIR)/$(PROJECT).xsa: $(BUILD_DIR)/$(PROJECT).xpr
	# Generate the Xilinx support archive for the current project
	$(VIVADO) $(VIVADO_ARGS) -source scripts/xsa.tcl -tclargs $(PROJECT)

$(BUILD_DIR)/pl.dtbo: $(BUILD_DIR)/dts/pl.dtsi
	dtc -O dtb -o $@ -b 0 -@ $<

$(BUILD_DIR)/$(PROJECT).bin: $(BUILD_DIR)/$(PROJECT).bit
	echo "all:{ $< }" > $(@D)/$(PROJECT).bif
	bootgen -image $(@D)/$(PROJECT).bif -arch zynq -process_bitstream bin -w -o $(@D)/$(PROJECT).bit.bin
	mv $(@D)/$(PROJECT).bit.bin $@

$(BUILD_DIR)/$(PROJECT).bit: $(BUILD_DIR)/$(PROJECT).runs/impl_1
	# Build the bitstream from the current project
	$(VIVADO) $(VIVADO_ARGS) -source scripts/bitstream.tcl -tclargs $(PROJECT)

$(BUILD_DIR)/$(PROJECT).runs/impl_1: $(BUILD_DIR)/$(PROJECT).xpr
	# Run the implementation script for the current project
	$(VIVADO) $(VIVADO_ARGS) -source scripts/impl.tcl -tclargs $(PROJECT)

$(BUILD_DIR)/$(PROJECT).xpr: $(SOURCES)
	# Create the project directory
	mkdir -p $(@D)
	# Run the project script
	$(VIVADO) $(VIVADO_ARGS) -source scripts/project.tcl -tclargs $(PROJECT) $(PART) $(@D)

$(ADI_HDL_ALL):
	$(MAKE) -C $(@D) all

$(ADI_HDL_CLEAN):
	$(MAKE) -C $(@D) clean

$(RPN_CORES_BUILD_DIRS): $(RPN_CORE_FILES)
	# Build the IPs of the red-pitaya-notes project
	$(MAKE) -C $(RPN_DIR) tmp/cores/$(notdir $@)

build/zImage.bin: build/linux-$(LINUX_VERSION)
	# Adapted from Pavel Demin's 'red-pitaya-notes' project
	# Builds the Linux kernel using the modified CMA with
	# the 'xilinx_zynq_defconfig' configuration.
	#
	# Clean the Linux build directory
	$(MAKE) -C $< mrproper
	# Cross-compile Linux for Red Pitaya
	$(MAKE) -C $< ARCH=arm \
		CROSS_COMPILE=arm-linux-gnueabihf- \
		-j $(shell nproc 2> /dev/null || echo 1) \
		LOADADDR=0x8000 \
		xilinx_zynq_defconfig \
		zImage \
		modules
	cp $</arch/arm/boot/zImage $@

build/linux-$(LINUX_VERSION): $(LINUX_OTHER_SOURCES)
	mkdir -p $@
	# Download Linux source and unpack to build directory
	curl -L --output - $(LINUX_TARBALL) | tar x --xz --strip-components 1 -C $@
	# Patch Linux to include additional drivers
	patch -d $(@D) -p 0 <linux/linux-$(LINUX_VERSION).patch
	patch -d $(@D) -p 0 <linux/linux-configfs-$(LINUX_VERSION).patch
	# Copy additional sources and the configuration
	cp linux/xilinx_zynq_defconfig $@/arch/arm/configs
	cp linux/configfs.c $@/drivers/of

build/fpgautil.c:
	# Download fpgautil
	curl -L --output $@ $(FPGAUTIL_C)

build/fpgautil: build/fpgautil.c
	arm-linux-gnueabihf-gcc $< -o $@

$(BUILD_DIR)/software/%: ./projects/$(PROJECT)/software/%.c
	mkdir -p -- $(@D)
	$(MAKE) -C $(<D) BUILD_DIR=$(abspath $(@D)) $(abspath $@.elf)
	mv -- $@.elf $@

.PHONY: verilator-lint
verilator-lint: $(HDL_FILES)
	verilator config.vlt $(HDL_INCLUDES) $(HDL_FILES) $(YOSYS_SIM) --lint-only --timing

.PHONY: verible-lint
verible-lint: $(HDL_FILES)
	verible-verilog-lint $(HDL_FILES)

.PHONY: test
test:
	scripts/test.sh

