#include "adcctl.h"
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>

int open_adc_config(int fd, struct adc_config *config) {
    config->_mmap = mmap(
        NULL,
        ADC_CONFIG_ADDR_RANGE,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        ADC_CONFIG_ADDR
    );
    if (config->_mmap == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory for ADC config register\n");
        return -errno;
    }
    config->config = (uint8_t *)&config->_mmap[0];
    config->status = &config->_mmap[1];
    config->adc_reg = &config->_mmap[2];
    return 0;
}

int open_packetizer(int fd, struct packetizer *pack) {
    unsigned int offset = PACKETIZER_ADDR - ADC_CONFIG_ADDR;
    pack->_mmap = mmap(
        NULL,
        offset + PACKETIZER_ADDR_RANGE,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        ADC_CONFIG_ADDR
    );
    if (pack->_mmap == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory for packetizer register\n");
        return -errno;
    }
    pack->config = &pack->_mmap[(offset / sizeof(uint32_t)) + 0];
    pack->status = &pack->_mmap[(offset / sizeof(uint32_t)) + 1];
    return 0;
}

int open_adc_trigger(int fd, struct adc_trigger *trigger) {
    unsigned int offset = ADC_TRIGGER_ADDR - ADC_CONFIG_ADDR;
    trigger->_mmap = mmap(
        NULL,
        offset + ADC_TRIGGER_ADDR_RANGE,
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        ADC_CONFIG_ADDR
    );
    if (trigger->config == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory for ADC trigger register\n");
        return -errno;
    }
    trigger->config = &trigger->_mmap[(offset / sizeof(uint32_t)) + 0];
    trigger->divider = &trigger->_mmap[(offset / sizeof(uint32_t)) + 1];
    return 0;
}

int open_adc(struct adc *adc) {
    int rc, fd;
    fd = open("/dev/mem", O_RDWR);
    rc = open_adc_config(fd, &adc->config);
    if (rc < 0) {
        close(fd);
        return rc;
    }
    rc = open_packetizer(fd, &adc->pack);
    if (rc < 0) {
        close(fd);
        return rc;
    }
    rc = open_adc_trigger(fd, &adc->trigger);
    close(fd);
    if (rc < 0) {
        return rc;
    }
    return 0;
}

int close_adc(struct adc *adc) {
    close_adc_config(&adc->config);
    close_packetizer(&adc->pack);
    close_adc_trigger(&adc->trigger);
    return 0;
}

int close_adc_config(struct adc_config *config) {
    munmap(config->config, sizeof(*config->config));
    munmap(config->status, sizeof(*config->status));
    munmap(config->adc_reg, sizeof(*config->adc_reg));
    return 0;
}

int close_packetizer(struct packetizer *pack) {
    munmap(pack->config, sizeof(*pack->config));
    munmap(pack->status, sizeof(*pack->status));
    return 0;
}

int close_adc_trigger(struct adc_trigger *trigger) {
    munmap(trigger->config, sizeof(*trigger->config));
    munmap(trigger->divider, sizeof(*trigger->divider));
    return 0;
}

void write_adc_reg(struct adc_config *config, uint32_t data) {
    *(config->adc_reg) = data;
}
