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
#define BUFFER_SIZE  (128 * 1024)

#define FINISH_XFER _IOW('a', 'a', int32_t *)
#define START_XFER  _IOW('a', 'b', int32_t *)
#define XFER        _IOR('a', 'c', int32_t *)

struct channel_buffer {
    uint32_t buffer[BUFFER_SIZE / sizeof(uint32_t)];
    enum proxy_status {
        PROXY_NO_ERROR = 0,
        PROXY_BUSY = 1,
        PROXY_TIMEOUT = 2,
        PROXY_ERROR = 3
    } status;
    unsigned int length;
    unsigned int period_len;
} __attribute__((aligned(1024))); /* 64 byte alignment required for DMA, but
                                     1024 handy for viewing memory */
