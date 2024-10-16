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
	$(MAKE) build/projects/$(name)/
endif

build/projects/%/:
	# Create target directory
	mkdir -p $(@D)
	# Run the project script
	$(VIVADO) -source scripts/project.tcl -tclargs $* $(PART) $@

clean:
	# Remove the build directory
	rm -rf build

