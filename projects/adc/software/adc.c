#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "adcctl.h"
#include "dmaclient.h"

int main(int argc, char *argv[]) {
    struct dma_channel channel;
    struct adc adc;
    int rc;

    rc = open_dma_channel(&channel);
    if (rc < 0) {
        exit(-rc);
    }
    channel.buffer->length = BUFFER_SIZE;
    channel.buffer->period_len = 10 * sizeof(uint32_t);

    rc = open_adc(&adc);
    if (rc < 0) {
        exit(-rc);
    }

    *adc.config.config = ADC_PWR_EN | ADC_IO_EN;
    // Wait one second for power to stabilize
    sleep(1);
    write_adc_reg(&adc.config, ADC_REG_ENTER);
    uint8_t mode = ADC_REG_MODE_4_LANE | ADC_REG_MODE_SPI_CLK |
                   ADC_REG_MODE_SDR | ADC_REG_MODE_TEST;
    write_adc_reg(&adc.config, ADC_REG(0, ADC_REG_MODE_ADDR, mode));
    write_adc_reg(&adc.config, ADC_REG_EXIT);
    sleep(1);

    *adc.trigger.config = ADC_TRIGGER_ONCE;
    *adc.pack.config = channel.buffer->period_len;
    *adc.trigger.divider = 50;

    printf("Start transfer\n");
    ioctl(channel.fd, START_XFER);
    ioctl(channel.fd, FINISH_XFER);
    close_adc(&adc);
    for (int i = 0; i < channel.buffer->period_len; i++) {
        printf("%d\n", channel.buffer->buffer[0]);
    }
    close_dma_channel(&channel);
}
