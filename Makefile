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
SPI_ENGINE_IPS := $(dir $(shell find library/analog_devices_hdl/library/spi_engine -name Makefile))
AXI_PWM_GEN_IP := $(dir $(shell find library/analog_devices_hdl/library/axi_pwm_gen -name Makefile))
_ADI_HDL_ALL := $(addsuffix all, $(SPI_ENGINE_IPS))
_ADI_HDL_ALL += $(addsuffix all, $(AXI_PWM_GEN_IP))
_ADI_HDL_CLEAN := $(addsuffix clean, $(SPI_ENGINE_IPS))
_ADI_HDL_CLEAN += $(addsuffix clean, $(AXI_PWM_GEN_IP))

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
SOURCES += $(_ADI_HDL_CLEAN)

PROJECTS = $(subst ./projects/,,$(wildcard ./projects/*))

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

.PHONY: adihdl
adihdl: $(_ADI_HDL_ALL)

.PHONY: clean
clean: $(_ADI_HDL_CLEAN)
	# Remove the build directory
	rm -rf build

