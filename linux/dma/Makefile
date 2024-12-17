ifneq ($(KERNELRELEASE),)
	obj-m: dmadc.o
else
LINUX_VERSION ?= 6.12
KERNEL_DIR ?= ../../build/linux-$(LINUX_VERSION)
MAKE_FLAGS := ARCH=arm
MAKE_FLAGS += CROSS_COMPILE=arm-linux-gnueabihf-

default:
	$(MAKE) -C $(KERNEL_DIR) $(MAKE_FLAGS) M=$$PWD

modules_install: default
ifndef INSTALL_MOD_PATH
	$(error INSTALL_MOD_PATH is undefined)
endif
	$(MAKE) INSTALL_MOD_PATH=$(INSTALL_MOD_PATH) -C $(KERNEL_DIR) $(MAKE_FLAGS) M=$$PWD

clean:
	$(MAKE) -C $(KERNEL_DIR) $(MAKE_FLAGS) M=$$PWD clean

.PHONY: default modules_install clean

endif
