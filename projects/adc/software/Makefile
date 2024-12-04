CFLAGS = -O0 -march=armv7-a -mtune=cortex-a9

BUILD_DIR ?= .

.PHONY: all clean
all: $(BUILD_DIR)/adc.elf

clean:
	rm -- $(BUILD_DIR)/adc.elf

$(BUILD_DIR)/%.elf: %.c
	/usr/bin/arm-linux-gnueabihf-gcc $(CFLAGS) -o $@ $^

