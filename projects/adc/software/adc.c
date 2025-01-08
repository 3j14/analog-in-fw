#include <adc.h>
#include <argp.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "adcctl.h"
#include "dmaclient.h"

#define yesno(b) (b) ? "yes" : "no"

static error_t parse_args(int key, char *arg, struct argp_state *state) {
    struct adc_arguments *args = state->input;
    switch (key) {
        case 'i':
            if (args->is_output_num_set)
                argp_error(state, INFO_MUTUALLY_EXCLUSIVE_ERROR);
            args->info = true;
            break;
        case 'o':
            if (args->info)
                argp_error(state, INFO_MUTUALLY_EXCLUSIVE_ERROR);
            args->is_output_num_set = true;
            args->output = arg;
            break;
        case 'n':
            if (args->info)
                argp_error(state, INFO_MUTUALLY_EXCLUSIVE_ERROR);
            args->is_output_num_set = true;
            args->num = (size_t)atoi(arg);
            if (args->num < MIN_NUM_SAMPLES || args->num > MAX_NUM_SAMPLES)
                argp_error(
                    state,
                    "Invalid number of samples '%s'. "
                    "Min number of samples: %u, max: %u",
                    arg,
                    MIN_NUM_SAMPLES,
                    MAX_NUM_SAMPLES
                );
            break;
        default:
            return ARGP_ERR_UNKNOWN;
    }
    return 0;
}

static struct argp argp = {options, parse_args, 0, adc_docs};

int main(int argc, char *argv[]) {
    struct adc_arguments args;
    args.info = false;
    args.is_output_num_set = false;
    args.output = DEFAULT_OUTPUT_FILE;
    args.num = DEFAULT_NUM_SAMPLES;
    argp_parse(&argp, argc, argv, 0, 0, &args);

    struct adc adc;
    int rc;

    rc = open_adc(&adc);
    if (rc < 0) {
        exit(-rc);
    }

    if (args.info) {
        bool transaction_active = get_adc_transaction_active(&adc.config);
        bool reg_available = get_adc_reg_available(&adc.config);
        uint8_t dev_mode = get_adc_device_mode(&adc.config);
        char *dev_mode_str =
            (dev_mode == ADC_STATUS_MODE_CONV)              ? "conv"
            : (dev_mode == ADC_STATUS_MODE_REG_ACCESS_ONCE) ? "reg_access_once"
            : (dev_mode == ADC_STATUS_MODE_REG_ACCESS)      ? "reg_access"
                                                            : "err";
        char *trigger_config_str =
            (*adc.trigger.config == ADC_TRIGGER_ONCE)         ? "trigger_once"
            : (*adc.trigger.config == ADC_TRIGGER_CONTINUOUS) ? "continuous"
            : (*adc.trigger.config == ADC_TRIGGER_CLEAR)      ? "clear"
                                                              : "err";

        uint32_t last_reg = get_adc_last_reg(&adc.config);
        puts("ADC Status:");
        printf(
            "adc_config transaction_active:  %s\n", yesno(transaction_active)
        );
        printf("adc_config reg_available:       %s\n", yesno(reg_available));
        printf("adc_config device_mode:         %s\n", dev_mode_str);
        printf("adc_config last_reg:            0x%X\n", last_reg);
        printf("adc_config config:              0x%X\n", *adc.config.config);
        printf("adc_config axis_reg:            0x%X\n", *adc.config.adc_reg);
        printf("packetizer config:              %u\n", *adc.pack.config);
        printf("packetizer status (counter):    %u\n", *adc.pack.status);
        printf("adc_trigger config:             %s\n", trigger_config_str);
        printf("adc_trigger divider:            %u\n", *adc.trigger.divider);
    } else {
        struct dma_channel channel;
        rc = open_dma_channel(&channel);
        if (rc < 0) {
            exit(-rc);
        }
        channel.buffer->length = BUFFER_SIZE;
        channel.buffer->period_len = args.num * sizeof(uint32_t);

        *adc.config.config = ADC_PWR_EN | ADC_IO_EN;
        // Wait one second for power to stabilize
        sleep(1);
        write_adc_reg(&adc.config, ADC_REG_ENTER);
        uint8_t mode = ADC_REG_MODE_4_LANE | ADC_REG_MODE_SPI_CLK |
                       ADC_REG_MODE_SDR | ADC_REG_MODE_TEST;
        write_adc_reg(&adc.config, ADC_REG(0, ADC_REG_MODE_ADDR, mode));
        write_adc_reg(&adc.config, ADC_REG_EXIT);

        *adc.trigger.config = ADC_TRIGGER_CLEAR;
        *adc.trigger.config = ADC_TRIGGER_ONCE;
        *adc.pack.config = args.num;
        *adc.trigger.divider = 50;

        printf("Transfer size: %u\n", args.num);
        sleep(1);
        printf("Start transfer\n");

        ioctl(channel.fd, START_XFER);
        ioctl(channel.fd, FINISH_XFER);
        // TODO: Write to file instead of print
        for (int i = 0; i < channel.buffer->period_len / sizeof(uint32_t);
             i++) {
            printf("0x%X\n", channel.buffer->buffer[0]);
        }
        close_dma_channel(&channel);
        adc.trigger.divider = 0;
    }
    close_adc(&adc);
}
