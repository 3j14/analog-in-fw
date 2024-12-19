#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

#include "adc.h"
#include "dmadc.h"

void reg_write(struct adc_config *adc, uint32_t data) {
    *(adc->adc_reg) = data;
}

struct dma_channel {
    struct channel_buffer *buffer;
    int fd;
};

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s num_transfers", argv[0]);
        exit(EXIT_FAILURE);
    }

    struct dma_channel channel;
    channel.fd = open("/dev/dmadc", O_RDWR);
    if (channel.fd == -1) {
        printf("Unable to open '/dev/dmadc'. Is the driver loaded?");
        exit(errno);
    }
    // Map the buffer from kernel to user space
    channel.buffer = (struct channel_buffer *)mmap(
        NULL,
        sizeof(struct channel_buffer),
        PROT_READ,
        MAP_SHARED,
        channel.fd,
        0
    );
    if (channel.buffer == MAP_FAILED) {
        printf("Unable to map memory from kernel");
        exit(errno);
    }

    printf("Start transfer");
    ioctl(channel.fd, START_XFER);
}
