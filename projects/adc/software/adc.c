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

    rc = open_adc(&adc);
    if (rc < 0) {
        exit(-rc);
    }

    // Enable power and IO
    *adc.config.config =
        ADC_PWR_EN | ~ADC_REF_EN | ADC_IO_EN | ~ADC_DIFFAMP_EN | ~ADC_OPAMP_EN;
    // Wait one second for power to stabilize
    sleep(1);
    write_adc_reg(&adc.config, ADC_REG_ENTER);
    uint8_t mode = ADC_REG_MODE_4_LANE | ADC_REG_MODE_SPI_CLK |
                   ADC_REG_MODE_SDR | ADC_REG_MODE_TEST;
    write_adc_reg(&adc.config, ADC_REG(0, ADC_REG_MODE_ADDR, mode));
    write_adc_reg(&adc.config, ADC_REG_EXIT);

    close_adc(&adc);

    /*printf("Start transfer");*/
    /*ioctl(channel.fd, START_XFER);*/
    close_dma_channel(&channel);
}
