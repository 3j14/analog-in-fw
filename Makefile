SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

PROJECT ?= blink
PART ?= xc7z010clg400-1
VIVADO = vivado
VIVADO_ARGS ?= -mode batch -log build/vivado.log -journal build/vivado.jou

SOURCES = $(wildcard ./library/*/*.v) \
		  $(wildcard ./library/*/*.sv) \
		  $(wildcard ./projects/$(PROJECT)/*.v) \
		  $(wildcard ./projects/$(PROJECT)/*.sv) \
		  $(wildcard ./projects/$(PROJECT)/*.tcl) \
		  $(wildcard ./contraints/*.xdc) \
		  $(wildcard ./contraints/*.tcl)

test:
	echo $(SOURCES)

PROJECTS = $(subst ./projects/,,$(wildcard ./projects/*))

build/projects/$(PROJECT)/$(PROJECT).xpr: projects/$(PROJECT)/
	mkdir -p $(@D)
	# Run the project script
	$(VIVADO) $(VIVADO_ARGS) -source scripts/project.tcl -tclargs $(PROJECT) $(PART) $(@D)

build/projects/$(PROJECT)/$(PROJECT).runs/impl_1: build/projects/$(PROJECT)/$(PROJECT).xpr
	# TODO: Run impl

.PHONY: clean
clean:
	# Remove the build directory
	rm -rf build

