#include <stdint.h>

#define ADC_PWR_EN     (uint8_t)2 ^ 3;
#define ADC_REF_EN     (uint8_t)2 ^ 4;
#define ADC_IO_EN      (uint8_t)2 ^ 5;
#define ADC_DIFFAMP_EN (uint8_t)2 ^ 6;
#define ADC_OPAMP_EN   (uint8_t)2 ^ 7;

// Helper to create ADC register read/write commands
#define ADC_REG(read, addr, data) (uint32_t)((read << 23) | (addr << 8) | data)

// Default ADC register commands
#define ADC_REG_EXIT  ADC_REG(0, 0x14, 1)
#define ADC_REG_ENTER (uint32_t)(0b101 << 21)

#define ADC_ADDR_CONFIG  0x40000000
#define ADC_ADDR_STATUS  0x40000004
#define ADC_ADDR_ADC_REG 0x40000008
struct adc_config {
    int *fd;
    uint8_t *config;
    uint32_t *status;
    uint32_t *adc_reg;
};

#define PACKETIZER_ADDR_CONFIG 0x40000200
#define PACKETIZER_ADDR_STATUS 0x40000204
struct packetizer {
    int *fd;
    uint32_t *config;
    uint32_t *status;
};

#define ADC_CONTINUOUS    (uint32_t)1
#define ADC_TRIGGER_CLEAR (uint32_t)2

#define ADC_TRIGGER_ADDR_CONFIG  0x40000100
#define ADC_TRIGGER_ADDR_DIVIDER 0x40000104
struct adc_trigger {
    int *fd;
    uint32_t *config;
    uint32_t *divider;
};

int get_adc_config(struct adc_config *adc);
int get_packetizer(struct packetizer *pack);
int get_adc_trigger(struct adc_trigger *trigger);
void reg_write(struct adc_config *adc, uint32_t data);
