/**
 * Copyright (C) 2024-2025 Jonas Drotleff
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

#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/dma-mapping.h>
#include <linux/dmaengine.h>
#include <linux/fs.h>
#include <linux/ioctl.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/of_dma.h>
#include <linux/platform_device.h>
#include <linux/uaccess.h>
#include <linux/version.h>
#include <linux/workqueue.h>

#include "asm-generic/errno-base.h"
#include "asm/page.h"
#include "dmadc.h"
#include "linux/dev_printk.h"
#include "linux/dma-direction.h"
#include "linux/gfp_types.h"
#include "linux/kern_levels.h"
#include "linux/printk.h"
#include "linux/property.h"

#define DRIVER_NAME      "dmadc"
#define ERROR            -1
#define DMADC_TIMEOUT_MS 10000

/**
 * struct dmadc_channel - DMA channel context
 * @buffer:                 Pointer to the coherent DMA buffer. The underlying
 *                          data type is uint32_t, as transfers from the ADC are
 *                          32 bit wide.
 * @dma_handle:             DMA handle for mmap operations.
 * @transfer_size:          Size of current transfer in bytes. Has to be a
 *                          multiple of the size of *buffer.
 * @dma_addr:               DMA address for current transfer.
 * @dma_addr_mapped:        Flag indicating if dma_addr is currently mapped.
 * @dma_dev:                Device for DMA operations (device of this kernel
 *                          driver).
 * @cdev:                   Char device structure.
 * @dmadc_dev:              Actual device under /dev/dmadc.
 * @dev_node:               Char device node.
 * @class_p:                Device class.
 * @dma_channel:            DMA engine channel.
 * @transfer_completion:    Completion for transfer synchronization.
 * @cookie:                 DMA cookie for current transfer.
 * @timeout_ms:             Transfer timeout in milliseconds. Can be set using
 *                          the SET_TIMEOUT_MS ioctl call.
 */
struct dmadc_channel {
    uint32_t *buffer;
    dma_addr_t dma_handle;

    u32 transfer_size;
    dma_addr_t dma_addr;
    bool dma_addr_mapped;

    struct device *dma_dev;

    struct cdev cdev;
    struct device *dmadc_dev;
    dev_t dev_node;
    struct class *class_p;

    struct dma_chan *dma_channel;
    struct completion transfer_completion;
    dma_cookie_t cookie;

    unsigned int timeout_ms;
};

/**
 * sync_callback - Callback for DMA operations. Syncs the buffer for cache
 *      coherency, unmaps the buffer and sets the completion.
 * @data: Pointer to the dmadc_channel struct instance of this device.
 */
static void sync_callback(void *data) {
    struct dmadc_channel *channel = (struct dmadc_channel *)data;

    /* Sync buffer for CPU access after DMA completion */
    dma_sync_single_for_cpu(
        channel->dma_dev,
        channel->dma_addr,
        channel->transfer_size,
        DMA_FROM_DEVICE
    );

    /* Unmap the DMA buffer */
    dma_unmap_single(
        channel->dma_dev,
        channel->dma_addr,
        channel->transfer_size,
        DMA_FROM_DEVICE
    );
    channel->dma_addr_mapped = false;

    /* Signal completion */
    complete(&channel->transfer_completion);
}

/**
 * start_transfer - Start a transfer of @size bytes.
 * @channel:    Pointer to the dmadc_channel instance of this device.
 * @size:       Size of the transfer in bytes. Has to be a multiple of the size
 *              of each transfer (8 bytes).
 */
static long start_transfer(struct dmadc_channel *channel, unsigned int size) {
    enum dma_ctrl_flags flags = DMA_CTRL_ACK | DMA_PREP_INTERRUPT;
    struct dma_async_tx_descriptor *chan_desc;

    // Check that the previous transfer has been completed. The completion is
    // always set to done when the driver is initialized such that the dma
    // channel is in a predicatble state.
    if (!completion_done(&channel->transfer_completion)) {
        printk(KERN_WARNING "Transfer already in progress\n");
        return -EBUSY;
    }
    // Transfer is done, we can reset the cookie. A cookie value of zero
    // indicates no current transfer.
    channel->cookie = 0;

    if (size > DMADC_BUFFER_SIZE) {
        printk(KERN_ERR "Requested size exceeds buffer capacity\n");
        return -EINVAL;
    }

    if (size % sizeof(*channel->buffer) != 0) {
        printk(
            KERN_ERR
            "Requested size is not a multiple of a single transfer %d \n",
            sizeof(*channel->buffer)
        );
        return -EINVAL;
    }

    if (size == 0) {
        printk(KERN_ERR "Invalid transfer size\n");
        return -EINVAL;
    }

    channel->transfer_size = size;

    channel->dma_addr = dma_map_single(
        channel->dma_dev, channel->buffer, size, DMA_FROM_DEVICE
    );
    if (dma_mapping_error(channel->dma_dev, channel->dma_addr)) {
        printk(KERN_ERR "dma_map_single() error\n");
        return dma_mapping_error(channel->dma_dev, channel->dma_addr);
    }
    channel->dma_addr_mapped = true;

    chan_desc = dmaengine_prep_slave_single(
        channel->dma_channel, channel->dma_addr, size, DMA_DEV_TO_MEM, flags
    );
    if (!chan_desc) {
        printk(KERN_ERR "dmaengine_prep_slave_single() error\n");
        dma_unmap_single(
            channel->dma_dev, channel->dma_addr, size, DMA_FROM_DEVICE
        );
        channel->dma_addr_mapped = false;
        channel->cookie = -EFAULT;
        return channel->cookie;
    }

    chan_desc->callback = sync_callback;
    chan_desc->callback_param = channel;

    // Reset completion to uncompleted state
    init_completion(&channel->transfer_completion);

    channel->cookie = dmaengine_submit(chan_desc);
    if (dma_submit_error(channel->cookie)) {
        printk(KERN_ERR "Submit error\n");
        dma_unmap_single(
            channel->dma_dev, channel->dma_addr, size, DMA_FROM_DEVICE
        );
        channel->dma_addr_mapped = false;
        return dma_submit_error(channel->cookie);
    }

    dma_async_issue_pending(channel->dma_channel);
    return 0;
}

/**
 * get_status - Get the transfer status of the dmadc_channel.
 * @channel: Pointer to the dmadc_channel instance.
 */
static enum dmadc_status get_status(struct dmadc_channel *channel) {
    if (channel->cookie == 0)
        return DMADC_NO_TRANSFER;
    if (channel->cookie < 0)
        return DMADC_SUBMIT_ERROR;

    enum dma_status status = dma_async_is_tx_complete(
        channel->dma_channel, channel->cookie, NULL, NULL
    );
    switch (status) {
        case DMA_COMPLETE:
            return DMADC_COMPLETE;
        case DMA_IN_PROGRESS:
            return DMADC_IN_PROGRESS;
        case DMA_PAUSED:
            return DMADC_PAUSED;
        default:
            return DMADC_ERROR;
    }
}

/**
 * wait_for_transfer - Blocking wait with timeout until transfer is complete.
 * @channel: Pointer to the dmadc_channel instance.
 */
static enum dmadc_status wait_for_transfer(struct dmadc_channel *channel) {
    if (channel->cookie == 0)
        return DMADC_NO_TRANSFER;
    if (channel->cookie < 0)
        return DMADC_SUBMIT_ERROR;
    enum dmadc_status status = get_status(channel);
    switch (status) {
        case DMADC_IN_PROGRESS:
        case DMADC_PAUSED:
            if (wait_for_completion_timeout(
                    &channel->transfer_completion,
                    msecs_to_jiffies(channel->timeout_ms)
                ) == 0) {
                printk(KERN_DEBUG "DMA timed out\n");
                return DMADC_TIMEOUT;
            }
            return get_status(channel);
        default:
            return status;
    }
}

static int mmap(struct file *file_p, struct vm_area_struct *vma) {
    unsigned long size = vma->vm_end - vma->vm_start;
    unsigned long offset = vma->vm_pgoff << PAGE_SHIFT;
    struct dmadc_channel *channel =
        (struct dmadc_channel *)file_p->private_data;

    if (size > DMADC_BUFFER_SIZE) {
        printk(KERN_ERR "mmap: Requested memory range is too large\n");
        return -EINVAL;
    }
    if (offset != 0) {
        printk(KERN_ERR "mmap: Page offset has to be 0\n");
        return -EINVAL;
    }

    return dma_mmap_coherent(
        channel->dma_dev, vma, channel->buffer, channel->dma_handle, size
    );
}

static int local_open(struct inode *ino, struct file *file) {
    file->private_data = container_of(ino->i_cdev, struct dmadc_channel, cdev);
    return 0;
}

static int release(struct inode *ino, struct file *file) {
    struct dmadc_channel *channel = (struct dmadc_channel *)file->private_data;
    struct dma_device *dma_device = channel->dma_channel->device;

    dma_device->device_terminate_all(channel->dma_channel);
    wait_for_transfer(channel);

    // Clean up remaining dma mappings
    if (channel->dma_addr_mapped) {
        dma_unmap_single(
            channel->dma_dev,
            channel->dma_addr,
            channel->transfer_size,
            DMA_FROM_DEVICE
        );
        channel->dma_addr_mapped = false;
    }

    // Reset completion and cookie for next call to open
    channel->cookie = 0;
    init_completion(&channel->transfer_completion);
    complete(&channel->transfer_completion);
    return 0;
}

static long ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
    struct dmadc_channel *channel = (struct dmadc_channel *)file->private_data;
    unsigned int size;
    unsigned int timeout_ms;
    enum dmadc_status status;
    int rc;
    unsigned int start_result;

    switch (cmd) {
        case START_TRANSFER:
            rc =
                copy_from_user(&size, (unsigned int __user *)arg, sizeof(size));
            if (rc)
                return -EINVAL;
            rc = (int)start_transfer(channel, size);
            start_result = (rc < 0) ? -rc : 0;
            rc = copy_to_user(
                (unsigned int __user *)arg, &start_result, sizeof(start_result)
            );
            if (rc)
                return -EINVAL;
            break;
        case WAIT_FOR_TRANSFER:
            status = wait_for_transfer(channel);
            rc = copy_to_user(
                (enum dmadc_status __user *)arg, &status, sizeof(status)
            );
            if (rc)
                return -EINVAL;
            break;
        case STATUS:
            status = get_status(channel);
            rc = copy_to_user(
                (enum dmadc_status __user *)arg, &status, sizeof(status)
            );
            if (rc)
                return -EINVAL;
            break;
        case SET_TIMEOUT_MS:
            rc = copy_from_user(
                &timeout_ms, (unsigned int __user *)arg, sizeof(timeout_ms)
            );
            if (rc)
                return -EINVAL;
            channel->timeout_ms = timeout_ms;
            break;
        default:
            return -EINVAL;
    }
    return 0;
}

static struct file_operations dm_fops = {
    .owner = THIS_MODULE,
    .open = local_open,
    .release = release,
    .unlocked_ioctl = ioctl,
    .mmap = mmap
};

static int cdevice_init(struct dmadc_channel *channel) {
    int rc;

    rc = alloc_chrdev_region(&channel->dev_node, 0, 1, DRIVER_NAME);
    if (rc) {
        dev_err(channel->dma_dev, "unable to get a char device number\n");
        return rc;
    }

    cdev_init(&channel->cdev, &dm_fops);
    channel->cdev.owner = THIS_MODULE;

    rc = cdev_add(&channel->cdev, channel->dev_node, 1);
    if (rc) {
        dev_err(channel->dma_dev, "unable to add char device\n");
        goto init_error1;
    }

    channel->class_p = class_create(DRIVER_NAME);
    if (IS_ERR(channel->class_p)) {
        dev_err(channel->dma_dev, "unable to create class\n");
        rc = PTR_ERR_OR_ZERO(channel->class_p);
        channel->class_p = NULL;
        goto init_error2;
    }

    channel->dmadc_dev = device_create(
        channel->class_p, NULL, channel->dev_node, NULL, DRIVER_NAME
    );
    if (IS_ERR(channel->dmadc_dev)) {
        dev_err(channel->dma_dev, "unable to create the device\n");
        rc = PTR_ERR_OR_ZERO(channel->dmadc_dev);
        goto init_error3;
    }

    return 0;

init_error3:
    class_destroy(channel->class_p);

init_error2:
    cdev_del(&channel->cdev);

init_error1:
    unregister_chrdev_region(channel->dev_node, 1);
    return rc;
}

static void cdevice_exit(struct dmadc_channel *channel) {
    if (channel->dmadc_dev) {
        device_destroy(channel->class_p, channel->dev_node);
    }
    if (channel->class_p) {
        class_destroy(channel->class_p);
    }
    cdev_del(&channel->cdev);
    unregister_chrdev_region(channel->dev_node, 1);
}

static int dmadc_probe(struct platform_device *pdev) {
    int rc, channel_count;
    const char *name;
    struct dmadc_channel *channel;
    struct device *dev = &pdev->dev;

    printk(KERN_INFO "dmadc module initialized\n");

    channel_count = device_property_string_array_count(dev, "dma-names");
    if (channel_count < 0) {
        dev_err(
            dev,
            "Could not get DMA names from device tree. Is 'dma-names' "
            "present?\n"
        );
        return channel_count;
    }
    if (channel_count != 1) {
        dev_err(
            dev,
            "Invalid number of DMA names. Only one DMA channel is supported.\n"
        );
        return ERROR;
    }

    rc = device_property_read_string(dev, "dma-names", &name);
    if (rc < 0)
        return rc;

    channel = devm_kmalloc(dev, sizeof(struct dmadc_channel), GFP_KERNEL);
    if (!channel) {
        dev_err(dev, "Could not allocate DMA channel\n");
        return -ENOMEM;
    }

    channel->dma_channel = dma_request_chan(dev, name);
    if (IS_ERR(channel->dma_channel)) {
        dev_err(dev, "Unable to request DMA channel '%s'\n", name);
        return PTR_ERR(channel->dma_channel);
    }

    channel->dma_dev = dev;

    // Allocate single DMA buffer that will be shared/mapped by user space
    channel->buffer = (uint32_t *)dmam_alloc_coherent(
        dev, DMADC_BUFFER_SIZE, &channel->dma_handle, GFP_KERNEL
    );
    if (!channel->buffer) {
        dev_err(dev, "DMA allocation error\n");
        return ERROR;
    }

    printk(
        KERN_INFO "Allocated single buffer of %u bytes\n", DMADC_BUFFER_SIZE
    );

    // Initialize channel state
    channel->transfer_size = 0;
    channel->dma_addr_mapped = false;
    channel->timeout_ms = DMADC_TIMEOUT_MS;
    channel->cookie = 0;
    init_completion(&channel->transfer_completion);
    complete(&channel->transfer_completion);

    rc = cdevice_init(channel);
    if (rc)
        return rc;

    dev_set_drvdata(dev, channel);
    return 0;
}

static void dmadc_remove(struct platform_device *pdev) {
    struct device *dev = &pdev->dev;
    struct dmadc_channel *channel = dev_get_drvdata(dev);

    cdevice_exit(channel);
    dma_release_channel(channel->dma_channel);
    printk(KERN_INFO "dmadc module exited\n");
}

static const struct of_device_id dmadc_of_ids[] = {
    {
        .compatible = "3j14,dmadc",
    },
    {}
};

static struct platform_driver dmadc_driver = {
    .driver =
        {
            .name = "dmadc_driver",
            .owner = THIS_MODULE,
            .of_match_table = dmadc_of_ids,
        },
    .probe = dmadc_probe,
    .remove = dmadc_remove,
};

static int __init dmadc_init(void) {
    return platform_driver_register(&dmadc_driver);
}

static void __exit dmadc_exit(void) {
    platform_driver_unregister(&dmadc_driver);
}

module_init(dmadc_init);
module_exit(dmadc_exit);

MODULE_AUTHOR("Xilinx, Inc.");
MODULE_AUTHOR("Jonas Drotleff");
MODULE_DESCRIPTION("DMA ADC");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("0.3");
