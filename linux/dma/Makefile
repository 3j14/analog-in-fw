ifneq ($(KERNELRELEASE),)
	obj-m: dmadc.o
else
LINUX_SOURCE_DIR ?= $(abspath ../../build/linux-6.12)
INSTALL_MOD_PATH ?= $(abspath ../../build/kernel)
LINUX_MAKE_FLAGS ?= ARCH=arm LLVM=1

default:
	$(MAKE) -C ../../$(LINUX_SOURCE_DIR) $(LINUX_MAKE_FLAGS) M=$$PWD

modules_install: default
	$(MAKE) -C ../../$(LINUX_SOURCE_DIR) INSTALL_MOD_PATH=$(INSTALL_MOD_PATH) $(LINUX_MAKE_FLAGS) modules_install M=$$PWD

clean:
	if [ -d "$(KERNEL_DIR)" ]; then $(MAKE) -C ../../$(LINUX_SOURCE_DIR) $(LINUX_MAKE_FLAGS) M=$$PWD clean; fi

.PHONY: default modules_install clean

endif
