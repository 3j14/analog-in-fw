SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

PROJECT ?= blink
PART ?= xc7z010clg400-1
VIVADO = vivado
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
_RED_PITAYA_NOTES_DIR := library/red-pitaya-notes
_PD_FILES := $(wildcard $(_RED_PITAYA_NOTES_DIR)/cores/*.v)
_PD_CORES := $(basename $(notdir $(_PD_FILES)))
_PD_CORES_BUILD_DIRS := $(addprefix $(_RED_PITAYA_NOTES_DIR)/tmp/cores/, $(_PD_CORES))

# Overwrite Analog Devices' Vivado version check
REQUIRED_VIVADO_VERSION ?= 2024.1.2
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
ifeq ($(PROJECT), spi)
SOURCES += $(_PD_CORES_BUILD_DIRS)
endif

PROJECTS = $(notdir $(wildcard ./projects/*))

build/projects/$(PROJECT)/$(PROJECT).xpr: $(SOURCES)
	mkdir -p $(@D)
	# Run the project script
	$(VIVADO) $(VIVADO_ARGS) -source scripts/project.tcl -tclargs $(PROJECT) $(PART) $(@D)

build/projects/$(PROJECT)/$(PROJECT).runs/impl_1: build/projects/$(PROJECT)/$(PROJECT).xpr
	$(VIVADO) $(VIVADO_ARGS) -source scripts/impl.tcl -tclargs $(PROJECT)

$(_ADI_HDL_ALL):
	$(MAKE) -C $(@D) all

$(_ADI_HDL_CLEAN):
	$(MAKE) -C $(@D) clean

$(_PD_CORES_BUILD_DIRS): $(_PD_FILES)
	$(MAKE) -C $(_RED_PITAYA_NOTES_DIR) tmp/cores/$(notdir $@)

