#include "dmaclient.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

int open_dma_channel(struct dma_channel *channel) {
    channel->fd = open("/dev/dmadc", O_RDWR);
    if (channel->fd == -1) {
        fprintf(stderr, "Unable to open '/dev/dmadc'. Is the driver loaded?\n");
        return -errno;
    }
    // Map the buffer from kernel to user space
    channel->buffer = (struct channel_buffer *)mmap(
        NULL,
        sizeof(struct channel_buffer),
        PROT_READ,
        MAP_SHARED,
        channel->fd,
        0
    );
    if (channel->buffer == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory from kernel\n");
        return -errno;
    }
    return 0;
}

int close_dma_channel(struct dma_channel *channel) {
    munmap(channel->buffer, sizeof(struct channel_buffer));
    // Close file descriptor for "/dev/dmadc". Any error returned from this
    // is ignored for now. If the file is no longer open, we don't care.
    close(channel->fd);
    return 0;
}
