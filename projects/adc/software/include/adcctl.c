#include "adcctl.h"
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>

int open_adc_config(int fd, struct adc_config *config) {
    config->config = mmap(
        NULL,
        sizeof(*config->config),
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        ADC_ADDR_CONFIG
    );
    if (config->config == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory for ADC config register\n");
        return -errno;
    }
    config->status = mmap(
        NULL,
        sizeof(*config->status),
        PROT_READ,
        MAP_SHARED,
        fd,
        ADC_ADDR_STATUS
    );
    if (config->status == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory for ADC status register\n");
        return -errno;
    }
    config->adc_reg = mmap(
        NULL,
        sizeof(*config->adc_reg),
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        ADC_ADDR_ADC_REG
    );
    if (config->adc_reg == MAP_FAILED) {
        fprintf(stderr, "Unable to map memory for ADC register\n");
        return -errno;
    }
    return 0;
}

int open_packetizer(int fd, struct packetizer *pack) {
    pack->config = mmap(
        NULL,
        sizeof(*pack->config),
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        PACKETIZER_ADDR_CONFIG
    );
    if (pack->config == MAP_FAILED) {
        fprintf(
            stderr, "Unable to map memory for packetizer config register\n"
        );
        return -errno;
    }
    pack->status = mmap(
        NULL,
        sizeof(*pack->status),
        PROT_READ,
        MAP_SHARED,
        fd,
        PACKETIZER_ADDR_STATUS
    );
    if (pack->status == MAP_FAILED) {
        fprintf(
            stderr, "Unable to map memory for packetizer status register\n"
        );
        return -errno;
    }
    return 0;
}

int open_adc_trigger(int fd, struct adc_trigger *trigger) {
    trigger->config = mmap(
        NULL,
        sizeof(*trigger->config),
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        ADC_TRIGGER_ADDR_CONFIG
    );
    if (trigger->config == MAP_FAILED) {
        fprintf(
            stderr, "Unable to map memory for ADC trigger config register\n"
        );
        return -errno;
    }
    trigger->divider = mmap(
        NULL,
        sizeof(*trigger->divider),
        PROT_READ | PROT_WRITE,
        MAP_SHARED,
        fd,
        ADC_TRIGGER_ADDR_DIVIDER
    );
    if (trigger->divider == MAP_FAILED) {
        fprintf(
            stderr, "Unable to map memory for ADC trigger divider register\n"
        );
        return -errno;
    }
    return 0;
}

int open_adc(struct adc *adc) {
    int rc;
    adc->fd = open("/dev/mem", O_RDWR);
    rc = open_adc_config(adc->fd, &adc->config);
    if (rc < 0) {
        close(adc->fd);
        return rc;
    }
    rc = open_packetizer(adc->fd, &adc->pack);
    if (rc < 0) {
        close(adc->fd);
        return rc;
    }
    rc = open_adc_trigger(adc->fd, &adc->trigger);
    if (rc < 0) {
        close(adc->fd);
        return rc;
    }
    return 0;
}

int close_adc(struct adc *adc) {
    close_adc_config(&adc->config);
    close_packetizer(&adc->pack);
    close_adc_trigger(&adc->trigger);
    close(adc->fd);
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
