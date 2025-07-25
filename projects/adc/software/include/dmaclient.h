#pragma once

#include "dmadc.h"
#include <stddef.h>

struct dmadc_channel {
    uint32_t *buffer;
    size_t mapped_size;
    int fd;
};

int open_dma_channel(struct dmadc_channel *channel);
int close_dma_channel(struct dmadc_channel *channel);
int dmadc_mmap(struct dmadc_channel *channel, size_t size);
int dmadc_mmap_buffer(struct dmadc_channel *channel, size_t size);
long start_transfer(struct dmadc_channel *channel, unsigned int size);
long set_timeout_ms(struct dmadc_channel *channel, unsigned int timeout_ms);
enum dmadc_status wait_for_transfer(struct dmadc_channel *channel);
enum dmadc_status get_status(struct dmadc_channel *channel);
