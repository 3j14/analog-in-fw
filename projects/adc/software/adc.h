#pragma once
#include <argp.h>
#include <dmadc.h>
#include <stdbool.h>
#include <stddef.h>

#define DEFAULT_OUTPUT_FILE "out.dat"
#define DEFAULT_DIVIDER     20
#define DEFAULT_TIMEOUT_MS  10000
#define DEFAULT_NUM_SAMPLES BUFFER_SIZE / sizeof(uint32_t)
#define MAX_NUM_SAMPLES     (BUFFER_SIZE * BUFFER_COUNT) / sizeof(uint32_t)
#define MAX_NUM_AVG         0x10

const char *argp_program_version = "adc 0.1.0";
const char adc_docs[] =
    "Read from the ADC using DMA or get ADC status information";
const struct argp_option options[] = {
    {"info", 'i', 0, 0, "Read the current status registers"},
    {"shutdown", 's', 0, 0, "Shutdown ADC and disable power"},
    {"div", 'd', "divider", 0, "Divider, defaults to 20"},
    {"avg", 'a', "averages", 0, "Averages, defaults to 0, max: 16"},
    {"timeout", 'w', "timeout_ms", 0, "Timeout, defaults to 10000"},
    {"test", 't', 0, 0, "Test pattern mode"},
    {"zone", 'z', "zone", 0, "Zone, can be either 1 or 2, default to 2"},
    {"output",
     'o',
     "file",
     0,
     "Output file for the data, defaults to " DEFAULT_OUTPUT_FILE},
    {"num", 'n', "count", 0, "Number of samples, defaults to 2048"},
    {0}
};

struct adc_arguments {
    bool info;
    bool shutdown;
    size_t div;
    size_t avg;
    bool test;
    char *output;
    size_t num;
    unsigned int timeout_ms;
    unsigned int zone;
};

static error_t parse_args(int key, char *arg, struct argp_state *state);

#undef _to_string_impl
#undef to_string
