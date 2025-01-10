#pragma once

#include "dmadc.h"

struct dmadc_channel {
    uint32_t *buffer;
    int fd;
};

int open_dma_channel(struct dmadc_channel *channel);
int close_dma_channel(struct dmadc_channel *channel);
long start_transfer(struct dmadc_channel *channel, unsigned int size);
enum dmadc_status wait_for_transfer(struct dmadc_channel *channel);
enum dmadc_status get_status(struct dmadc_channel *channel);
