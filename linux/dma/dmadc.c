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
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/version.h>
#include <linux/workqueue.h>

#include "dmadc.h"
#include "linux/dev_printk.h"
#include "linux/dma-direction.h"
#include "linux/kern_levels.h"
#include "linux/mm.h"
#include "linux/printk.h"
#include "linux/property.h"
#include "linux/scatterlist.h"

#define DRIVER_NAME      "dmadc"
#define ERROR            -1
#define DMADC_TIMEOUT_MS 10000

struct buffer {
    uint32_t *data;
    dma_addr_t phys_addr;
};

struct dmadc_channel {
    struct buffer *buffers[BUFFER_COUNT];
    struct scatterlist *sglist;
    /* Number of buffers used */
    u32 sg_len;

    struct device *dmadc_dev;
    struct device *dma_dev;
    dev_t dev_node;
    struct cdev cdev;
    struct class *class_p;

    struct dma_chan *dma_channel;
    struct completion cmp;
    dma_cookie_t cookie;
};

struct dmadc {
    struct dmadc_channel *dmadc_channel;
    struct work_struct work;
};

static void sync_callback(void *completion) { complete(completion); }

static long start_transfer(struct dmadc_channel *channel, unsigned int size) {
    unsigned int sg_count, buffer_count;
    enum dma_ctrl_flags flags = DMA_CTRL_ACK | DMA_PREP_INTERRUPT;
    struct dma_async_tx_descriptor *chan_desc;
    struct dma_device *dma_device = channel->dma_channel->device;

    buffer_count = DIV_ROUND_UP(size, BUFFER_SIZE);
    if (buffer_count > BUFFER_COUNT) {
        printk(KERN_ERR "Requested size exeeds available memory\n");
        return -EINVAL;
    }
    sg_count = dma_map_sg(
        channel->dma_dev, channel->sglist, buffer_count, DMA_FROM_DEVICE
    );
    if (sg_count == 0) {
        printk(KERN_ERR "dma_map_sg() error\n");
        return -EFAULT;
    }

    chan_desc = dma_device->device_prep_slave_sg(
        channel->dma_channel,
        channel->sglist,
        sg_count,
        DMA_DEV_TO_MEM,
        flags,
        NULL
    );
    if (!chan_desc) {
        printk(KERN_ERR "dmaengine_prep_slave_sg() error\n");
        dma_unmap_sg(
            channel->dma_dev, channel->sglist, buffer_count, DMA_FROM_DEVICE
        );
        return -EFAULT;
    }

    chan_desc->callback = sync_callback;
    chan_desc->callback_param = &channel->cmp;

    init_completion(&channel->cmp);

    channel->cookie = dmaengine_submit(chan_desc);
    if (dma_submit_error(channel->cookie)) {
        printk("Submit error\n");
        dma_unmap_sg(
            channel->dma_dev, channel->sglist, buffer_count, DMA_FROM_DEVICE
        );
        return -EFAULT;
    }

    dma_async_issue_pending(channel->dma_channel);
    return 0;
}

static enum dmadc_status get_status(struct dmadc_channel *channel) {
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

/* Wait for a DMA transfer that was previously submitted to the DMA engine
 */
static enum dmadc_status wait_for_transfer(struct dmadc_channel *channel) {
    unsigned long timeout = wait_for_completion_timeout(
        &channel->cmp, msecs_to_jiffies(DMADC_TIMEOUT_MS)
    );
    if (timeout == 0) {
        printk(KERN_ERR "DMA timed out\n");
        return DMADC_TIMEOUT;
    }
    return get_status(channel);
}

static int mmap(struct file *file_p, struct vm_area_struct *vma) {
    int i, rc;
    size_t size, map_size;
    struct dmadc_channel *channel =
        (struct dmadc_channel *)file_p->private_data;
    // Size of the memroy allocation. May be larger than the size of a single
    // buffer, so we iterate over all buffers and allocate as much memory as
    // needed.
    size = vma->vm_end - vma->vm_start;

    if (size > BUFFER_COUNT * BUFFER_SIZE)
        // Requested memory range is too large
        return -EINVAL;

    for (i = 0; i < BUFFER_COUNT; i++) {
        if (size <= 0)
            break;

        map_size = min(size, BUFFER_SIZE);
        rc = dma_mmap_coherent(
            channel->dma_dev,
            vma,
            channel->buffers[i]->data,
            channel->buffers[i]->phys_addr,
            map_size
        );
        if (rc)
            return rc;
        // The vm_area_struct struct has to be modified such that the bounds
        // are set correctly in the next iteration
        vma->vm_start += map_size;
        size -= map_size;
    }
    return 0;
}

/* Open the device file and set up the data pointer to the proxy channel data
 * for the proxy channel such that the ioctl function can access the data
 * structure later.
 */
static int local_open(struct inode *ino, struct file *file) {
    file->private_data = container_of(ino->i_cdev, struct dmadc_channel, cdev);

    return 0;
}

/* Close the file and there's nothing to do for it
 */
static int release(struct inode *ino, struct file *file) {
    struct dmadc_channel *pchannel_p =
        (struct dmadc_channel *)file->private_data;
    struct dma_device *dma_device = pchannel_p->dma_channel->device;

    dma_device->device_terminate_all(pchannel_p->dma_channel);
    return 0;
}

static long ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
    struct dmadc_channel *channel = (struct dmadc_channel *)file->private_data;
    unsigned int size;
    enum dmadc_status status;
    int rc;

    switch (cmd) {
        case START_TRANSFER:
            rc =
                copy_from_user(&size, (unsigned int __user *)arg, sizeof(size));
            if (rc)
                return -EINVAL;
            start_transfer(channel, size);
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

/* Initialize the driver to be a character device such that is responds to
 * file operations.
 */
static int cdevice_init(struct dmadc_channel *pchannel_p) {
    int rc;
    static struct class *local_class_p = NULL;

    /* Allocate a character device from the kernel for this driver.
     */
    rc = alloc_chrdev_region(&pchannel_p->dev_node, 0, 1, DRIVER_NAME);

    if (rc) {
        dev_err(pchannel_p->dma_dev, "unable to get a char device number\n");
        return rc;
    }

    /* Initialize the device data structure before registering the character
     * device with the kernel.
     */
    cdev_init(&pchannel_p->cdev, &dm_fops);
    pchannel_p->cdev.owner = THIS_MODULE;
    rc = cdev_add(&pchannel_p->cdev, pchannel_p->dev_node, 1);

    if (rc) {
        dev_err(pchannel_p->dma_dev, "unable to add char device\n");
        goto init_error1;
    }

    if (!local_class_p) {
        local_class_p = class_create(DRIVER_NAME);

        if (IS_ERR(local_class_p)) {
            dev_err(pchannel_p->dma_dev, "unable to create class\n");
            rc = ERROR;
            goto init_error2;
        }
    }
    pchannel_p->class_p = local_class_p;

    /* Create the device node in /dev so the device is accessible
     * as a character device
     */
    pchannel_p->dmadc_dev = device_create(
        pchannel_p->class_p, NULL, pchannel_p->dev_node, NULL, DRIVER_NAME
    );

    if (IS_ERR(pchannel_p->dmadc_dev)) {
        dev_err(pchannel_p->dma_dev, "unable to create the device\n");
        goto init_error3;
    }

    return 0;

init_error3:
    class_destroy(pchannel_p->class_p);

init_error2:
    cdev_del(&pchannel_p->cdev);

init_error1:
    unregister_chrdev_region(pchannel_p->dev_node, 1);
    return rc;
}

/* Exit the character device by freeing up the resources that it created and
 * disconnecting itself from the kernel.
 */
static void cdevice_exit(struct dmadc_channel *channel) {
    /* Take everything down in the reverse order
     * from how it was created for the char device
     */
    if (channel->dmadc_dev) {
        device_destroy(channel->class_p, channel->dev_node);
    }
    if (channel->class_p) {
        class_destroy(channel->class_p);
    }
    cdev_del(&channel->cdev);
    unregister_chrdev_region(channel->dev_node, 1);
}

/* Initialize the DMA ADC device driver module.
 */
static int dmadc_probe(struct platform_device *pdev) {
    int rc, i;
    int channel_count;
    const char *name;
    struct dmadc *dma;
    struct device *dev = &pdev->dev;

    printk(KERN_INFO "dmadc module initialized\n");

    // Count number of DMA channels. Only one channel is supported
    channel_count = device_property_string_array_count(dev, "dma-names");
    if (channel_count < 0) {
        dev_err(
            dev,
            "Could not get DMA names from device tree. Is 'dma-names' "
            "present?\n"
        );
        // channel_count is an error code
        return channel_count;
    }
    if (channel_count != 1) {
        dev_err(
            dev,
            "Invalid number of DMA names. Only one DMA channel is "
            "supported.\n"
        );
        return ERROR;
    }
    // Get DMA name from device tree
    rc = device_property_read_string(dev, "dma-names", &name);
    if (rc < 0)
        return rc;

    // Allocate memory for the dmadc struct
    dma = (struct dmadc *)devm_kmalloc(dev, sizeof(struct dmadc), GFP_KERNEL);
    if (!dma) {
        dev_err(dev, "Cound not allocate DMADC device\n");
        return -ENOMEM;
    }

    dma->dmadc_channel =
        devm_kmalloc(dev, sizeof(struct dmadc_channel), GFP_KERNEL);
    if (!dma->dmadc_channel) {
        dev_err(dev, "Cound not allocate DMA channel\n");
        return -ENOMEM;
    }
    dma->dmadc_channel->dma_channel = dma_request_chan(dev, name);
    if (IS_ERR(dma->dmadc_channel->dma_channel)) {
        dev_err(dev, "Unable to request DMA channel '%s'\n", name);
        return PTR_ERR(dma->dmadc_channel->dma_channel);
    }

    dma->dmadc_channel->dma_dev = dev;

    sg_init_table(dma->dmadc_channel->sglist, BUFFER_COUNT);
    for (i = 0; i < BUFFER_COUNT; i++) {
        // Allocate DMA memory that will be shared/mapped by user space
        dma->dmadc_channel->buffers[i]->data = (uint32_t *)dmam_alloc_coherent(
            dev,
            BUFFER_SIZE,
            &dma->dmadc_channel->buffers[i]->phys_addr,
            GFP_KERNEL
        );
        if (!dma->dmadc_channel->buffers[i]) {
            dev_err(dev, "DMA allocation error\n");
            return ERROR;
        }
        printk(
            KERN_DEBUG
            "Allocating memory, virtual address: %px physical address: %px\n",
            dma->dmadc_channel->buffers[i]->data,
            (void *)dma->dmadc_channel->buffers[i]->phys_addr
        );
        sg_set_buf(
            &dma->dmadc_channel->sglist[i],
            dma->dmadc_channel->buffers[i]->data,
            BUFFER_SIZE
        );
    }
    dma->dmadc_channel->sg_len = BUFFER_COUNT;

    // Setup chartacter device
    rc = cdevice_init(dma->dmadc_channel);
    if (rc)
        return rc;

    dev_set_drvdata(dev, dma);
    return 0;
}

/* Exit the dma proxy device driver module.
 */
static void dmadc_remove(struct platform_device *pdev) {
    struct device *dev = &pdev->dev;
    struct dmadc *dma = dev_get_drvdata(dev);

    // Exit char device
    cdevice_exit(dma->dmadc_channel);
    // Release DMA channel
    dma_release_channel(dma->dmadc_channel->dma_channel);
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
