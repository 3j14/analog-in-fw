ifneq ($(KERNELRELEASE),)
	obj-m: dmadc.o
else
LINUX_VERSION ?= 6.12
KERNEL_DIR ?= $(abspath ../../build/linux-$(LINUX_VERSION))
INSTALL_MOD_PATH ?= $(abspath ../../build/kernel)
MAKE_FLAGS := ARCH=arm
MAKE_FLAGS += LLVM=1

default:
	$(MAKE) -C $(KERNEL_DIR) $(MAKE_FLAGS) M=$$PWD

modules_install: default
	$(MAKE) INSTALL_MOD_PATH=$(INSTALL_MOD_PATH) -C $(KERNEL_DIR) $(MAKE_FLAGS) modules_install M=$$PWD

clean:
	if [ -d "$(KERNEL_DIR)" ]; then $(MAKE) -C $(KERNEL_DIR) $(MAKE_FLAGS) M=$$PWD clean; fi

.PHONY: default modules_install clean

endif
