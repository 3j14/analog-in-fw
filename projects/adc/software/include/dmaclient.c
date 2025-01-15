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

    // Make sure all pointers to buffers are initiallized with null pointers
    for (unsigned int i = 0; i < BUFFER_COUNT; i++) {
        channel->buffers[i] = NULL;
    }

    return 0;
}

int dmadc_mmap(struct dmadc_channel *channel, size_t buffer_index) {
    off_t offset = (buffer_index * BUFFER_SIZE);
    void *buffer = mmap(
        NULL,
        BUFFER_SIZE,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        channel->fd,
        offset
    );
    if (buffer == MAP_FAILED) {
        return -errno;
    }
    channel->buffers[buffer_index] = (uint32_t *)buffer;
    return 0;
}

int dmadc_mmap_buffers(struct dmadc_channel *channel, size_t size) {
    int rc;
    size_t i, buffers = (size / BUFFER_SIZE);
    if (size % BUFFER_SIZE != 0)
        buffers += 1;
    for (i = 0; i < buffers; i++) {
        rc = dmadc_mmap(channel, i);
        if (rc < 0) {
            return rc;
        }
    }
    return 0;
}

int close_dma_channel(struct dmadc_channel *channel) {
    for (unsigned int i = 0; i < BUFFER_COUNT; i++) {
        if (channel->buffers[i] == NULL)
            continue;
        munmap(channel->buffers[i], BUFFER_SIZE);
    }
    // Close file descriptor for "/dev/dmadc". Any error returned from this
    // is ignored for now. If the file is no longer open, we don't care.
    close(channel->fd);
    return 0;
}

long start_transfer(struct dmadc_channel *channel, unsigned int size) {
    return ioctl(channel->fd, START_TRANSFER, &size);
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
