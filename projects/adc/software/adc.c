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
#include "dmadc.h"

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
            if (args->num > MAX_NUM_SAMPLES)
                argp_error(
                    state,
                    "Invalid number of samples '%s'. Max: %u",
                    arg,
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
    struct adc adc;
    int rc;
    size_t i;
    enum dmadc_status status;
    struct adc_arguments args;
    FILE *outfile;
    args.info = false;
    args.is_output_num_set = false;
    args.output = DEFAULT_OUTPUT_FILE;
    args.num = DEFAULT_NUM_SAMPLES;
    argp_parse(&argp, argc, argv, 0, 0, &args);

    rc = open_adc(&adc);
    if (rc < 0) {
        exit(-rc);
    }

    if (args.info) {
        bool trans_active = get_adc_transaction_active(&adc.config);
        bool reg_available = get_adc_reg_available(&adc.config);
        bool tvalid = get_adc_tvalid(&adc.config);
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
        printf("adc_config transaction_active:  %s\n", yesno(trans_active));
        printf("adc_config reg_available:       %s\n", yesno(reg_available));
        printf("adc_config tvalid:              %s\n", yesno(tvalid));
        printf("adc_config device_mode:         %s\n", dev_mode_str);
        printf("adc_config last_reg:            0x%X\n", last_reg);
        printf("adc_config config:              0x%X\n", *adc.config.config);
        printf("adc_config axis_reg:            0x%X\n", *adc.config.adc_reg);
        printf("packetizer config:              %u\n", *adc.pack.config);
        printf(
            "packetizer packet counter:      %u\n", *adc.pack.packet_counter
        );
        printf("packetizer iter counter:       %u\n", *adc.pack.iter_counter);
        printf("adc_trigger config:             %s\n", trigger_config_str);
        printf("adc_trigger divider:            %u\n", *adc.trigger.divider);
    } else {
        outfile = fopen(args.output, "w");
        if (outfile == NULL) {
            fprintf(stderr, "Unable to open file %s\n", args.output);
            close_adc(&adc);
            exit(-errno);
        }
        struct dmadc_channel channel;
        rc = open_dma_channel(&channel);
        if (rc < 0) {
            exit(-rc);
        }

        // Enable power
        *adc.config.config = ADC_PWR_EN | ADC_IO_EN;
        // Wait for power to stabilize
        usleep(250);

        // Configure ADC
        write_adc_reg(&adc.config, ADC_REG_ENTER);
        uint8_t mode = ADC_REG_MODE_4_LANE | ADC_REG_MODE_SPI_CLK |
                       ADC_REG_MODE_SDR | ADC_REG_MODE_TEST;
        write_adc_reg(&adc.config, ADC_REG(0, ADC_REG_MODE_ADDR, mode));
        write_adc_reg(&adc.config, ADC_REG_EXIT);

        // Configure trigger
        *adc.trigger.config = ADC_TRIGGER_CLEAR;
        *adc.trigger.config = ADC_TRIGGER_ONCE;
        *adc.trigger.divider = 50;
        printf("Transfer size: %u\n", args.num * sizeof(uint32_t));
        puts("Start transfer\n");

        start_transfer(&channel, args.num * sizeof(uint32_t));
        // Configure packetizer
        set_packatizer_save(&adc.pack, args.num);

        status = wait_for_transfer(&channel);
        switch (status) {
            case DMADC_COMPLETE:
                puts("Completed DMA transfer");
                break;
            case DMADC_TIMEOUT:
                fprintf(stderr, "Error: DMA timed out\n");
            default:
                status = get_status(&channel);
                fprintf(
                    stderr,
                    "Error: DMA transfer exited with status %s\n",
                    dmadc_status_strings[status]
                );
                break;
        }
        puts("Mapping buffers...");
        rc = dmadc_mmap_buffers(&channel, args.num * sizeof(uint32_t));
        printf("Done, result: %d\n", rc);
        size_t total_buffers = args.num * sizeof(uint32_t) / BUFFER_SIZE;
        size_t buffers_mod = (args.num * sizeof(uint32_t)) % BUFFER_SIZE;
        for (i = 0; i < args.num * sizeof(uint32_t) / BUFFER_SIZE; i++) {
            if (channel.buffers[i] == NULL)
                continue;
            fwrite(
                channel.buffers[i],
                sizeof(uint32_t),
                BUFFER_SIZE / sizeof(uint32_t),
                outfile
            );
        }
        if (buffers_mod > 0)
            if (channel.buffers[total_buffers + 1] != NULL) {
                fwrite(
                    channel.buffers[total_buffers + 1],
                    sizeof(uint32_t),
                    buffers_mod / sizeof(uint32_t),
                    outfile
                );
            }
        puts("Closing DMA channel...");
        close_dma_channel(&channel);
        *adc.trigger.divider = 0;
        set_packatizer_save(&adc.pack, 0);
        fclose(outfile);
    }
    close_adc(&adc);
}
