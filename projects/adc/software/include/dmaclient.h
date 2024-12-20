#pragma once

#include "dmadc.h"

struct dma_channel {
    struct channel_buffer *buffer;
    int fd;
};

int open_dma_channel(struct dma_channel *channel);
int close_dma_channel(struct dma_channel *channel);
