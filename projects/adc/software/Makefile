ifneq ("$(wildcard ~/.local/arm-*linux-gnueabihf/arm-*linux-gnueabihf/sysroot)","")
LOCAL_SYSROOT=1
SYSROOT ?= $(wildcard ~/.local/arm-*linux-gnueabihf/arm-*linux-gnueabihf/sysroot)
else
LOCAL_SYSROOT=0
SYSROOT ?= $(wildcard /usr/arm-*linux-gnueabihf)
endif

DMA_DIR := $(abspath ../../../linux/dma)

CC := clang
CFLAGS ?= -O0
override CFLAGS += --sysroot=$(SYSROOT)
ifneq ("$(LOCAL_SYSROOT)","0")
override CFLAGS += --gcc-toolchain=$(SYSROOT)/../..
endif
override CFLAGS += -I$(DMA_DIR) -I. -Iinclude

SOURCES := $(wildcard *.[ch])
SOURCES += $(wildcard include/*.[ch])
SOURCES += $(DMA_DIR)/dmadc.h
OBJECTS := $(patsubst %.c,%.o,$(wildcard *.c))
OBJECTS += $(patsubst %.c,%.o,$(wildcard include/*.c))

test:
	echo $(SOURCES)
TARGET := adc
BUILD_DIR ?= .

.PHONY: all clean
all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(addprefix $(BUILD_DIR)/,$(OBJECTS))
	$(CC) $(CFLAGS) -fuse-ld=lld $^ -o $@

$(BUILD_DIR)/include/%.o: include/%.c $(SOURCES)
$(BUILD_DIR)/%.o: %.c $(SOURCES)
	mkdir -p -- $(@D)
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -rf -- $(BUILD_DIR)/$(TARGET)
	rm -rf -- $(addprefix $(BUILD_DIR)/,$(OBJECTS))


