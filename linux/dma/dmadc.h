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
// 2048 bytes (~2KB) correspond to 512 transfers, half of the fifo size.
// Transfers can only be multiples of the buffer size.
#define BUFFER_SIZE 2048

enum dmadc_status {
    DMADC_COMPLETE,
    DMADC_IN_PROGRESS,
    DMADC_PAUSED,
    DMADC_ERROR,
    DMADC_TIMEOUT,
};

#define START_TRANSFER    _IOW('a', 'a', unsigned int *)
#define WAIT_FOR_TRANSFER _IOR('a', 'b', enum dmadc_status *)
#define STATUS            _IOR('a', 'c', enum dmadc_status *)
