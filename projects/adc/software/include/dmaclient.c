#include "dmaclient.h"
#include "dmadc.h"

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

int open_dma_channel(struct dmadc_channel *channel) {
    channel->fd = open("/dev/dmadc", O_RDWR);
    if (channel->fd == -1) {
        fprintf(stderr, "Unable to open '/dev/dmadc'. Is the driver loaded?\n");
        return -errno;
    }
    channel->buffer = NULL;
    channel->mapped_size = 0;

    return 0;
}

int dmadc_mmap(struct dmadc_channel *channel, size_t size) {
    if (size > DMADC_BUFFER_SIZE) {
        fprintf(
            stderr,
            "Requested size %zu exceeds buffer capacity %u\n",
            size,
            DMADC_BUFFER_SIZE
        );
        return -EINVAL;
    }

    void *buffer =
        mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, channel->fd, 0);
    if (buffer == MAP_FAILED) {
        return -errno;
    }
    channel->buffer = (uint32_t *)buffer;
    channel->mapped_size = size;
    return 0;
}

int dmadc_mmap_buffer(struct dmadc_channel *channel, size_t size) {
    return dmadc_mmap(channel, size);
}

int close_dma_channel(struct dmadc_channel *channel) {
    if (channel->buffer != NULL && channel->mapped_size > 0) {
        munmap(channel->buffer, channel->mapped_size);
        channel->buffer = NULL;
        channel->mapped_size = 0;
    }
    // Close file descriptor for "/dev/dmadc". Any errors returned from this
    // are ignored for now. If the file is no longer open, we don't care.
    close(channel->fd);
    return 0;
}

long start_transfer(struct dmadc_channel *channel, unsigned int size) {
    unsigned int size_and_rc = size;
    long rc = ioctl(channel->fd, START_TRANSFER, &size_and_rc);
    if (rc != 0)
        return -errno;
    return size_and_rc;
}

long set_timeout_ms(struct dmadc_channel *channel, unsigned int timeout_ms) {
    unsigned int _timeout = timeout_ms;
    long rc = ioctl(channel->fd, SET_TIMEOUT_MS, &_timeout);
    if (rc != 0)
        return -errno;
    return 0;
}

enum dmadc_status wait_for_transfer(struct dmadc_channel *channel) {
    enum dmadc_status status = DMADC_ERROR;
    int rc = ioctl(channel->fd, WAIT_FOR_TRANSFER, &status);
    if (rc) {
        return DMADC_ERROR;
    }
    return status;
}

enum dmadc_status get_status(struct dmadc_channel *channel) {
    enum dmadc_status status = DMADC_ERROR;
    int rc = ioctl(channel->fd, STATUS, &status);
    if (rc) {
        return DMADC_ERROR;
    }
    return status;
}
