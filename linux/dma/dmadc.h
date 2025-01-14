/**
 * Copyright (C) 2024 Jonas Drotleff
 * Copyright (C) 2021 Xilinx, Inc
 *
 * Licensed under the Apache License, Version 2.0 (the "License"). You may
 * not use this file except in compliance with the License. A copy of the
 * License is located at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
#pragma once

// Include types.h if compiled as a linux module, else stdint.h
#ifdef MODULE
#include <linux/types.h>
#else
#include <stdint.h>
#endif

#define BUFFER_COUNT 1024
// Size of each buffer in bytes. A transfer is 32 bit so 4 bytes.
// 4096 bytes (~2KB) correspond to 1024 transfers, equal to the fifo size.
// Buffer size should be a multiple of the page size.
#define BUFFER_SIZE 4096

enum dmadc_status {
    DMADC_COMPLETE = 0,
    DMADC_IN_PROGRESS = 1,
    DMADC_PAUSED = 2,
    DMADC_ERROR = 3,
    DMADC_TIMEOUT = 4,
};
static const char *dmadc_status_strings[] = {
    "complete", "in progresss", "paused", "error", "timeout"
};

#define START_TRANSFER    _IOW('a', 'a', unsigned int *)
#define WAIT_FOR_TRANSFER _IOR('a', 'b', enum dmadc_status *)
#define STATUS            _IOR('a', 'c', enum dmadc_status *)
