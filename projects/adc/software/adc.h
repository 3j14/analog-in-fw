#pragma once
#include <argp.h>
#include <dmadc.h>
#include <stdbool.h>
#include <stddef.h>

#define DEFAULT_OUTPUT_FILE "out.dat"
#define DEFAULT_NUM_SAMPLES 128
#define MIN_NUM_SAMPLES     128
#define MAX_NUM_SAMPLES     BUFFER_SIZE / sizeof(uint32_t)

#define INFO_MUTUALLY_EXCLUSIVE_ERROR \
    "--info is mutually exclusive with --output and --num"

// Helpers to include convert integer definitions to strings
#define _to_string_impl(s) #s
#define to_string(s)       _to_string_impl(s)

const char *argp_program_version = "adc 0.1.0";
const char adc_docs[] =
    "Read from the ADC using DMA or get ADC status information";
const struct argp_option options[] = {
    {"info",
     'i',
     0,
     0,
     "Read the current status registers. Mutually exclusive with 'output' and "
     "'num'"},
    {"output",
     'o',
     "file",
     0,
     "Output file for the data, defaults to " DEFAULT_OUTPUT_FILE},
    {"num",
     'n',
     "count",
     0,
     "Number of samples (min. " to_string(DEFAULT_NUM_SAMPLES
     ) ", defaults to " to_string(DEFAULT_NUM_SAMPLES) ")"},
    {0}
};

struct adc_arguments {
    bool info;
    bool is_output_num_set;
    char *output;
    size_t num;
};

static error_t parse_args(int key, char *arg, struct argp_state *state);

#undef _to_string_impl
#undef to_string
