SHELL=/bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

PART ?= xc7z010clg400-1
VIVADO = vivado -nolog -nojournal

project:
ifeq ($(name),)
	@echo "Error: 'name' not set. Usage: make project name=<project_name>"
	@exit 1
else
	$(MAKE) build/projects/$(name).xpr
endif

build/projects/%/project.xpr:
	# Create target directory
	mkdir -p $(@D)
	$(VIVADO) -source projects/$*/system_project.tcl -tclargs $* $(PART) $@

