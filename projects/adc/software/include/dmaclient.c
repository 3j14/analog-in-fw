#include "dmaclient.h"
#include "dmadc.h"

#include <errno.h>
#include <fcntl.h>
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
    // Map the buffer from kernel to user space
    channel->buffer = (uint32_t *)mmap(
        NULL, BUFFER_COUNT * BUFFER_SIZE, PROT_READ, MAP_SHARED, channel->fd, 0
    );
    if (channel->buffer == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory from kernel\n");
        return -errno;
    }
    return 0;
}

int close_dma_channel(struct dmadc_channel *channel) {
    munmap(channel->buffer, BUFFER_SIZE * BUFFER_COUNT);
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
