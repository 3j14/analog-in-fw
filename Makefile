SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

PROJECT ?= blink
PART ?= xc7z010clg400-1
PROCESSOR ?= ps7_cortexa9_0
VIVADO = vivado
XSCT = xsct
VITIS = vitis
VIVADO_MODE ?= batch
VIVADO_ARGS ?= -mode $(VIVADO_MODE) -log build/vivado.log -journal build/vivado.jou
_VIVADO := $(VIVADO) $(VIVADO_ARGS)

# Targets for Analog Devices' SPI Engine
_ADI_HDL_DIR := library/adi-hdl
_ADI_HDL_IPS := $(dir $(shell find $(_ADI_HDL_DIR)/library/spi_engine -name Makefile))
_ADI_HDL_IPS += $(dir $(shell find $(_ADI_HDL_DIR)/library/axi_pwm_gen -name Makefile))
_ADI_HDL_IPS += $(dir $(shell find $(_ADI_HDL_DIR)/library/ad463x_data_capture -name Makefile))
_ADI_HDL_ALL := $(addsuffix all, $(_ADI_HDL_IPS))
_ADI_HDL_CLEAN := $(addsuffix clean, $(_ADI_HDL_IPS))

# Targets for Pavel Demin's Red Pitaya Notes
_RPN_DIR := library/red-pitaya-notes
_PD_FILES := $(wildcard $(_RPN_DIR)/cores/*.v)
_PD_CORES := $(basename $(notdir $(_PD_FILES)))
_PD_CORES_BUILD_DIRS := $(addprefix $(_RPN_DIR)/tmp/cores/, $(_PD_CORES))

HDL_FILES := $(shell find library \( -path $(_RPN_DIR) -o -path $(_ADI_HDL_DIR) \) -prune -false -o -name \*.v -o -name \*.sv)
HDL_FILES += $(shell find projects -name \*.v -o -name \*.sv)

# Overwrite Analog Devices' Vivado version check
REQUIRED_VIVADO_VERSION ?= 2024.2
export REQUIRED_VIVADO_VERSION

SOURCES := $(wildcard ./library/*/*.v)
SOURCES += $(wildcard ./library/*/*.sv)
SOURCES += $(wildcard ./projects/$(PROJECT)/*.v)
SOURCES += $(wildcard ./projects/$(PROJECT)/*.sv)
SOURCES += $(wildcard ./projects/$(PROJECT)/*.tcl)
SOURCES += $(wildcard ./contraints/*.xdc)
SOURCES += $(wildcard ./contraints/*.tcl)
ifeq ($(PROJECT), spitest)
SOURCES += $(_ADI_HDL_ALL)
endif
ifeq ($(PROJECT), adc)
SOURCES += $(_PD_CORES_BUILD_DIRS)
endif

BUILD_DIR = build/projects/$(PROJECT)
PROJECTS = $(notdir $(wildcard ./projects/*))

define bootbif
img:
{
	[bootloader] $(BUILD_DIR)/fsbl/fsbl.elf $(_RPN_DIR)/tmp/ssbl.elf
	[load=0x2000000] $(BUILD_DIR)/initrd.dtb
	[load=0x2008000] $(_RPN_DIR)/zImage.bin
	[load=0x3000000] $(BUILD_DIR)/initrd.dtb
}
endef
define boot-rootfsbif
img:
{
	[bootloader] $(BUILD_DIR)/fsbl/fsbl.elf $(_RPN_DIR)/tmp/ssbl.elf
	[load=0x2000000] $(BUILD_DIR)/rootfs.dtb
	[load=0x2008000] $(_RPN_DIR)/zImage.bin
}
endef
.PHONY: fsbl xsa bitstream impl project clean
dtb: $(BUILD_DIR)/rootfs.dtb $(BUILD_DIR)/initrd.dtb
fsbl: $(BUILD_DIR)/fsbl/fsbl.elf
ssbl: $(_RPN_DIR)/tmp/ssbl.elf
xsa: $(BUILD_DIR)/$(PROJECT).xsa
bitstream: $(BUILD_DIR)/$(PROJECT).bit
impl: $(BUILD_DIR)/$(PROJECT).runs/impl_1
project: $(BUILD_DIR)/$(PROJECT).xpr
clean: $(_ADI_HDL_CLEAN)
	rm -rf $(_RPN_DIR)/tmp
	rm -rf build

$(BUILD_DIR)/boot.bin: fsbl ssbl dtb
	echo "$(bootbif)" > $(@D)/boot.bif
	bootgen -image $(@D)/boot.bif -w -o $@

$(BUILD_DIR)/boot-rootfs.bin: fsbl ssbl dtb
	echo "$(boot-rootfsbif)" > $(@D)/boot-rootfs.bif
	bootgen -image $(@D)/boot-rootfs.bif -w -o $@

$(BUILD_DIR)/rootfs.dtb: $(BUILD_DIR)/dts/system-top.dts $(_RPN_DIR)/dts
	dtc -I dts -O dtb -o $@ \
		-i $(BUILD_DIR)/dts \
		-i $(BUILD_DIR)/fsbl/hw/sdt \
		-i $(BUILD_DIR)/fsbl/hw/sdt/include \
		-i $(BUILD_DIR)/fsbl/hw/sdt/include/dt-binding \
		-i $(_RPN_DIR)/dts \
		$(_RPN_DIR)/dts/rootfs.dts

$(BUILD_DIR)/initrd.dtb: $(BUILD_DIR)/dts/system-top.dts $(_RPN_DIR)/dts
	dtc -I dts -O dtb -o $@ \
		-i $(BUILD_DIR)/dts \
		-i $(BUILD_DIR)/fsbl/hw/sdt \
		-i $(BUILD_DIR)/fsbl/hw/sdt/include \
		-i $(BUILD_DIR)/fsbl/hw/sdt/include/dt-binding \
		-i $(_RPN_DIR)/dts \
		$(_RPN_DIR)/dts/initrd.dts

$(BUILD_DIR)/dts/system-top.dts: $(BUILD_DIR)/fsbl/hw/sdt/system-top.dts
	mkdir -p $(@D)
	cp $< $@
	sed -i 's|#include|/include/|' $@

$(BUILD_DIR)/fsbl/hw/sdt/system-top.dts: $(BUILD_DIR)/fsbl

$(BUILD_DIR)/fsbl/fsbl.elf: $(BUILD_DIR)/fsbl
	$(VITIS) --source scripts/fsbl.py build $(PROJECT)
	cp $</zynq_fsbl/build/fsbl.elf $@

$(BUILD_DIR)/fsbl: $(BUILD_DIR)/$(PROJECT).xsa $(_RPN_DIR)/patches/red_pitaya_fsbl_hooks.c $(_RPN_DIR)/patches/fsbl.patch
	$(VITIS) --source scripts/fsbl.py create $(PROJECT)
	cp $(_RPN_DIR)/patches/red_pitaya_fsbl_hooks.c $@/zynq_fsbl
	patch $@/zynq_fsbl/fsbl_hooks.c $(_RPN_DIR)/patches/fsbl.patch
	sed -i 's\XPAR_PS7_ETHERNET_0_DEVICE_ID\0\g' $@/zynq_fsbl/red_pitaya_fsbl_hooks.c
	sed -i 's\XPAR_PS7_I2C_0_DEVICE_ID\0\g' $@/zynq_fsbl/red_pitaya_fsbl_hooks.c
	sed -i '/fsbl_hooks.c)/a collect (PROJECT_LIB_SOURCES red_pitaya_fsbl_hooks.c)' $@/zynq_fsbl/CMakeLists.txt

$(BUILD_DIR)/$(PROJECT).xsa: $(BUILD_DIR)/$(PROJECT).xpr
	$(VIVADO) $(VIVADO_ARGS) -source scripts/xsa.tcl -tclargs $(PROJECT)

$(BUILD_DIR)/$(PROJECT).bit: $(BUILD_DIR)/$(PROJECT).xpr
	$(VIVADO) $(VIVADO_ARGS) -source scripts/bitstream.tcl -tclargs $(PROJECT)

$(BUILD_DIR)/$(PROJECT).runs/impl_1: $(BUILD_DIR)/$(PROJECT).xpr
	$(VIVADO) $(VIVADO_ARGS) -source scripts/impl.tcl -tclargs $(PROJECT)

$(BUILD_DIR)/$(PROJECT).xpr: $(SOURCES)
	mkdir -p $(@D)
	# Run the project script
	$(VIVADO) $(VIVADO_ARGS) -source scripts/project.tcl -tclargs $(PROJECT) $(PART) $(@D)

$(_ADI_HDL_ALL):
	$(MAKE) -C $(@D) all

$(_ADI_HDL_CLEAN):
	$(MAKE) -C $(@D) clean

$(_PD_CORES_BUILD_DIRS): $(_PD_FILES)
	$(MAKE) -C $(_RPN_DIR) tmp/cores/$(notdir $@)

$(_RPN_DIR)/tmp/ssbl.elf:
	$(MAKE) -C $(_RPN_DIR) tmp/ssbl.elf

$(_RPN_DIR)/zImage.bin:
	$(MAKE) -C $(_RPN_DIR) $(@F)

$(_RPN_DIR)/initrd.bin:
	$(MAKE) -C $(_RPN_DIR) $(@F)

.PHONY: verilator-lint
verilator-lint: $(HDL_FILES)
	verilator config.vlt $(HDL_FILES) /usr/share/yosys/xilinx/cells_sim.v --lint-only --timing

.PHONY: verible-lint
verible-ling: $(HDL_FILES)
	verible-verilog-lint $(HDL_FILES)

