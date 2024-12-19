CC := clang
CFLAGS := -O0
CFLAGS += --target=arm-linux-gnueabihf
CFLAGS += --sysroot=/usr/arm-linux-gnueabihf
CFLAGS += -march=armv7-a
CFLAGS += -mtune=cortex-a9
CFLAGS += -meabi gnu
CFLAGS += -marm
CFLAGS += -std=gnu11
CFLAGS += -Uarm
CFLAGS += -Wall
CFLAGS += -fuse-ld=lld
CFLAGS += -I$(abspath ../../../linux/dma)

BUILD_DIR ?= .

.PHONY: all clean
all: $(BUILD_DIR)/adc.elf

clean:
	rm -- $(BUILD_DIR)/adc.elf

$(BUILD_DIR)/%.elf: %.c
	$(CC) $(CFLAGS) -o $@ $^

