#pragma once

#include <stdbool.h>
#include <stdint.h>

#define ADC_PWR_EN     (uint8_t)8
#define ADC_REF_EN     (uint8_t)16
#define ADC_IO_EN      (uint8_t)32
#define ADC_DIFFAMP_EN (uint8_t)64
#define ADC_OPAMP_EN   (uint8_t)128

// Helper to create ADC register read/write commands
#define ADC_REG(read, addr, data) (uint32_t)((read << 23) | (addr << 8) | data)

// Default ADC register commands
#define ADC_REG_EXIT               ADC_REG(0, 0x14, 1)
#define ADC_REG_ENTER              (uint32_t)(0b101 << 21)
#define ADC_REG_MODE_ADDR          0x20
#define ADC_REG_MODE_1_LANE        (uint8_t)0
#define ADC_REG_MODE_2_LANE        (uint8_t)(1 << 6)
#define ADC_REG_MODE_4_LANE        (uint8_t)(2 << 6)
#define ADC_REG_MODE_SPI_CLK       (uint8_t)0
#define ADC_REG_MODE_ECHO_CLK      (uint8_t)(1 << 4)
#define ADC_REG_MODE_HOST_CLK      (uint8_t)(2 << 4)
#define ADC_REG_MODE_SDR           (uint8_t)0
#define ADC_REG_MODE_DDR           (uint8_t)(1 << 3)
#define ADC_REG_MODE_24BIT         (uint8_t)0
#define ADC_REG_MODE_24BIT_COM     (uint8_t)1
#define ADC_REG_MODE_32BIT_COM     (uint8_t)2
#define ADC_REG_MODE_32BIT_AVERAGE (uint8_t)3
#define ADC_REG_MODE_TEST          (uint8_t)4

#define ADC_STATUS_MODE_CONV            (uint8_t)0
#define ADC_STATUS_MODE_REG_ACCESS_ONCE (uint8_t)2
#define ADC_STATUS_MODE_REG_ACCESS      (uint8_t)3

#define ADC_CONFIG_ADDR_RANGE 256
#define ADC_CONFIG_ADDR       0x40000000
struct adc_config {
    uint32_t *_mmap;
    uint8_t *config;
    uint32_t *status;
    uint32_t *adc_reg;
};

#define PACKETIZER_ADDR_RANGE 256
#define PACKETIZER_ADDR       0x40000200
struct packetizer {
    uint32_t *_mmap;
    uint32_t *config;
    uint32_t *status;
};

#define ADC_TRIGGER_ONCE       (uint32_t)0
#define ADC_TRIGGER_CONTINUOUS (uint32_t)1
#define ADC_TRIGGER_CLEAR      (uint32_t)2

#define ADC_TRIGGER_ADDR_RANGE 256
#define ADC_TRIGGER_ADDR       0x40000100
struct adc_trigger {
    uint32_t *_mmap;
    uint32_t *config;
    uint32_t *divider;
};
struct adc {
    struct adc_config config;
    struct packetizer pack;
    struct adc_trigger trigger;
};

int open_adc(struct adc *adc);
int close_adc(struct adc *adc);
int open_adc_config(int fd, struct adc_config *config);
int close_adc_config(struct adc_config *config);
int open_packetizer(int fd, struct packetizer *pack);
int close_packetizer(struct packetizer *pack);
int open_adc_trigger(int fd, struct adc_trigger *trigger);
int close_adc_trigger(struct adc_trigger *trigger);
void write_adc_reg(struct adc_config *config, uint32_t data);
void write_adc_reg(struct adc_config *config, uint32_t data);
bool get_adc_transaction_active(struct adc_config *config);
bool get_adc_reg_available(struct adc_config *config);
uint8_t get_adc_device_mode(struct adc_config *config);
uint32_t get_adc_last_reg(struct adc_config *config);
