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
CFLAGS += -I$(abspath ../../../linux/dma) -I. -Iinclude

SOURCES := $(wildcard *.[ch])
SOURCES += $(wildcard include/*.[ch])
OBJECTS := $(patsubst %.c,%.o,$(wildcard *.c))
OBJECTS += $(patsubst %.c,%.o,$(wildcard include/*.c))

TARGET := adc
BUILD_DIR ?= .

.PHONY: all clean
all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR)/$(TARGET): $(BUILD_DIR)/$(OBJECTS)
	$(CC) $(CFLAGS) -fuse-ld=lld $^ -o $@

$(BUILD_DIR)/include/%.o: include/%.c $(SOURCES)
$(BUILD_DIR)/%.o: %.c $(SOURCES)
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -- $(BUILD_DIR)/$(TARGET)
	rm -- $(BUILD_DIR)/$(OBJECTS)


