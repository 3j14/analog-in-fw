#pragma once
#include <argp.h>
#include <dmadc.h>
#include <stdbool.h>
#include <stddef.h>

#define DEFAULT_OUTPUT_FILE "out.dat"
#define DEFAULT_DIVIDER     20
#define DEFAULT_NUM_SAMPLES BUFFER_SIZE / sizeof(uint32_t)
#define MAX_NUM_SAMPLES     (BUFFER_SIZE * BUFFER_COUNT) / sizeof(uint32_t)

#define INFO_MUTUALLY_EXCLUSIVE_ERROR \
    "--info is mutually exclusive with --output, --num, -div, and --shutdown"

const char *argp_program_version = "adc 0.1.0";
const char adc_docs[] =
    "Read from the ADC using DMA or get ADC status information";
const struct argp_option options[] = {
    {"info",
     'i',
     0,
     0,
     "Read the current status registers. Mutually exclusive with 'output' "
     "and "
     "'num'"},
    {"shutdown",
     's',
     0,
     0,
     "Shutdown ADC and disable power. Mutually exclusive with all other "
     "options."},
    {"div", 'd', "divider", 0, "Divider, defaults to 20"},
    {"avg", 'a', "averages", 0, "Averages, defaults to 1"},
    {"output",
     'o',
     "file",
     0,
     "Output file for the data, defaults to " DEFAULT_OUTPUT_FILE},
    {"num", 'n', "count", 0, "Number of samples, defaults to 1024"},
    {0}
};

struct adc_arguments {
    bool info;
    bool shutdown;
    bool is_acquire_mode;
    size_t div;
    size_t avg;
    char *output;
    size_t num;
};

static error_t parse_args(int key, char *arg, struct argp_state *state);

#undef _to_string_impl
#undef to_string
