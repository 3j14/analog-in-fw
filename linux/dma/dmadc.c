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
#include "linux/property.h"

#define DRIVER_NAME "dmadc"
#define RX_CHANNEL 1
#define ERROR -1
#define DMA_TIMEOUT_MS 3000

struct dmadc_channel
{
    struct channel_buffer* buffer_table_p; /* user to kernel space interface */
    dma_addr_t buffer_phys_addr;

    struct device* proxy_device_p; /* character device support */
    struct device* dma_device_p;
    dev_t dev_node;
    struct cdev cdev;
    struct class* class_p;

    struct dma_chan* channel_p; /* dma support */
    u32 direction;              /* DMA_MEM_TO_DEV or DMA_DEV_TO_MEM */

    struct completion cmp;
    dma_cookie_t cookie;
};

struct dmadc
{
    struct dmadc_channel* channel;
    struct work_struct work;
};

/* Handle a callback and indicate the DMA transfer is complete to another
 * thread of control
 */
static void
sync_callback(void* completion)
{
    /* Indicate the DMA transaction completed to allow the other
     * thread of control to finish processing
     */
    complete(completion);
}

/* Prepare a DMA buffer to be used in a DMA transaction, submit it to the DMA
 * engine to be queued and return a cookie that can be used to track that
 * status of the transaction
 */
static void
start_transfer(struct dmadc_channel* pchannel_p)
{
    enum dma_ctrl_flags flags = DMA_CTRL_ACK | DMA_PREP_INTERRUPT;
    struct dma_async_tx_descriptor* chan_desc;

    struct dma_device* dma_device = pchannel_p->channel_p->device;

    chan_desc = dma_device->device_prep_dma_cyclic(
        pchannel_p->channel_p,
        pchannel_p->buffer_phys_addr,
        pchannel_p->buffer_table_p->length,
        pchannel_p->buffer_table_p->period_len,
        pchannel_p->direction,
        flags);

    if (!chan_desc) {
        printk(KERN_ERR "dmaengine_prep*() error\n");
        return;
    }

    chan_desc->callback = sync_callback;
    chan_desc->callback_param = &pchannel_p->cmp;

    init_completion(&pchannel_p->cmp);

    pchannel_p->cookie = dmaengine_submit(chan_desc);
    if (dma_submit_error(pchannel_p->cookie)) {
        printk("Submit error\n");
        return;
    }

    /* Start the DMA transaction which was previously queued up in the DMA
     * engine
     */
    dma_async_issue_pending(pchannel_p->channel_p);
}

/* Wait for a DMA transfer that was previously submitted to the DMA engine
 */
static void
wait_for_transfer(struct dmadc_channel* pchannel_p)
{
    unsigned long timeout = msecs_to_jiffies(DMA_TIMEOUT_MS);
    enum dma_status status;

    pchannel_p->buffer_table_p->status = PROXY_BUSY;

    /* Wait for the transaction to complete, or timeout, or get an error */
    timeout = wait_for_completion_timeout(&pchannel_p->cmp, timeout);
    status = dma_async_is_tx_complete(
        pchannel_p->channel_p, pchannel_p->cookie, NULL, NULL);

    if (timeout == 0) {
        pchannel_p->buffer_table_p->status = PROXY_TIMEOUT;
        printk(KERN_ERR "DMA timed out\n");
    } else if (status != DMA_COMPLETE) {
        pchannel_p->buffer_table_p->status = PROXY_ERROR;
        printk(
            KERN_ERR "DMA returned completion callback status of: %s\n",
            status == DMA_ERROR ? "error" : "in progress");
    } else
        pchannel_p->buffer_table_p->status = PROXY_NO_ERROR;
}

/* Map the memory for the channel interface into user space such that user space
 * can access it using coherent memory which will be non-cached for s/w coherent
 * systems such as Zynq 7K or the current default for Zynq MPSOC. MPSOC can be
 * h/w coherent when set up and then the memory will be cached.
 */
static int
mmap(struct file* file_p, struct vm_area_struct* vma)
{
    struct dmadc_channel* pchannel_p =
        (struct dmadc_channel*)file_p->private_data;

    return dma_mmap_coherent(
        pchannel_p->dma_device_p,
        vma,
        pchannel_p->buffer_table_p,
        pchannel_p->buffer_phys_addr,
        vma->vm_end - vma->vm_start);
}

/* Open the device file and set up the data pointer to the proxy channel data
 * for the proxy channel such that the ioctl function can access the data
 * structure later.
 */
static int
local_open(struct inode* ino, struct file* file)
{
    file->private_data = container_of(ino->i_cdev, struct dmadc_channel, cdev);

    return 0;
}

/* Close the file and there's nothing to do for it
 */
static int
release(struct inode* ino, struct file* file)
{
    struct dmadc_channel* pchannel_p =
        (struct dmadc_channel*)file->private_data;
    struct dma_device* dma_device = pchannel_p->channel_p->device;

    dma_device->device_terminate_all(pchannel_p->channel_p);
    return 0;
}

/* Perform I/O control to perform a DMA transfer using the input as an index
 * into the buffer descriptor table such that the application is in control of
 * which buffer to use for the transfer.The BD in this case is only a s/w
 * structure for the proxy driver, not related to the hw BD of the DMA.
 */
static long
ioctl(struct file* file, unsigned int cmd, unsigned long arg)
{
    struct dmadc_channel* pchannel_p =
        (struct dmadc_channel*)file->private_data;
    switch (cmd) {
        case START_XFER:
            start_transfer(pchannel_p);
            break;
        case FINISH_XFER:
            wait_for_transfer(pchannel_p);
            break;
        case XFER:
            start_transfer(pchannel_p);
            wait_for_transfer(pchannel_p);
            break;
    }
    return 0;
}

static struct file_operations dm_fops = { .owner = THIS_MODULE,
                                          .open = local_open,
                                          .release = release,
                                          .unlocked_ioctl = ioctl,
                                          .mmap = mmap };

/* Initialize the driver to be a character device such that is responds to
 * file operations.
 */
static int
cdevice_init(struct dmadc_channel* pchannel_p)
{
    int rc;
    static struct class* local_class_p = NULL;

    /* Allocate a character device from the kernel for this driver.
     */
    rc = alloc_chrdev_region(&pchannel_p->dev_node, 0, 1, DRIVER_NAME);

    if (rc) {
        dev_err(
            pchannel_p->dma_device_p, "unable to get a char device number\n");
        return rc;
    }

    /* Initialize the device data structure before registering the character
     * device with the kernel.
     */
    cdev_init(&pchannel_p->cdev, &dm_fops);
    pchannel_p->cdev.owner = THIS_MODULE;
    rc = cdev_add(&pchannel_p->cdev, pchannel_p->dev_node, 1);

    if (rc) {
        dev_err(pchannel_p->dma_device_p, "unable to add char device\n");
        goto init_error1;
    }

    if (!local_class_p) {
        local_class_p = class_create(DRIVER_NAME);

        if (IS_ERR(local_class_p)) {
            dev_err(pchannel_p->dma_device_p, "unable to create class\n");
            rc = ERROR;
            goto init_error2;
        }
    }
    pchannel_p->class_p = local_class_p;

    /* Create the device node in /dev so the device is accessible
     * as a character device
     */
    pchannel_p->proxy_device_p = device_create(
        pchannel_p->class_p, NULL, pchannel_p->dev_node, NULL, DRIVER_NAME);

    if (IS_ERR(pchannel_p->proxy_device_p)) {
        dev_err(pchannel_p->dma_device_p, "unable to create the device\n");
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
static void
cdevice_exit(struct dmadc_channel* pchannel_p)
{
    /* Take everything down in the reverse order
     * from how it was created for the char device
     */
    if (pchannel_p->proxy_device_p) {
        device_destroy(pchannel_p->class_p, pchannel_p->dev_node);
    }
    if (pchannel_p->class_p) {
        class_destroy(pchannel_p->class_p);
    }
    cdev_del(&pchannel_p->cdev);
    unregister_chrdev_region(pchannel_p->dev_node, 1);
}

/* Initialize the DMA ADC device driver module.
 */
static int
dmadc_probe(struct platform_device* pdev)
{
    int rc;
    int channel_count;
    const char* name;
    struct dmadc* dma;
    struct device* dev = &pdev->dev;

    printk(KERN_INFO "dmadc module initialized\n");

    // Count number of DMA channels. Only one channel is supported
    channel_count = device_property_string_array_count(dev, "dma-names");
    if (channel_count < 0) {
        dev_err(
            dev,
            "Could not get DMA names from device tree. Is 'dma-names' "
            "present?\n");
        // channel_count is an error code
        return channel_count;
    }
    if (channel_count != 1) {
        dev_err(
            dev,
            "Invalid number of DMA names. Only one DMA channel is "
            "supported.\n");
        return ERROR;
    }
    // Get DMA name from device tree
    rc = device_property_read_string(dev, "dma-names", &name);
    if (rc < 0)
        return rc;

    // Allocate memory for the dmadc struct
    dma = (struct dmadc*)devm_kmalloc(dev, sizeof(struct dmadc), GFP_KERNEL);
    if (!dma) {
        dev_err(dev, "Cound not allocate DMADC device\n");
        return -ENOMEM;
    }

    dma->channel = devm_kmalloc(dev, sizeof(struct dmadc_channel), GFP_KERNEL);
    if (!dma->channel) {
        dev_err(dev, "Cound not allocate DMA channel\n");
        return -ENOMEM;
    }
    dma->channel->channel_p = dma_request_chan(dev, name);
    if (IS_ERR(dma->channel->channel_p)) {
        dev_err(dev, "Unable to request DMA channel '%s'\n", name);
        return PTR_ERR(dma->channel->channel_p);
    }

    dma->channel->dma_device_p = dev;
    dma->channel->direction = DMA_DEV_TO_MEM;

    // Allocate DMA memory that will be shared/mapped by user space
    dma->channel->buffer_table_p = (struct channel_buffer*)dmam_alloc_coherent(
        dev,
        sizeof(struct channel_buffer),
        &dma->channel->buffer_phys_addr,
        GFP_KERNEL);
    if (!dma->channel->buffer_table_p) {
        dev_err(dev, "DMA allocation error\n");
        return ERROR;
    }

    printk(
        KERN_INFO
        "Allocating memory, virtual address: %px physical address: %px\n",
        dma->channel->buffer_table_p,
        (void*)dma->channel->buffer_phys_addr);

    // Setup chartacter device
    rc = cdevice_init(dma->channel);
    if (rc)
        return rc;

    dev_set_drvdata(dev, dma);
    return 0;
}

/* Exit the dma proxy device driver module.
 */
static void
dmadc_remove(struct platform_device* pdev)
{
    struct device* dev = &pdev->dev;
    struct dmadc* dma = dev_get_drvdata(dev);

    // Exit char device
    cdevice_exit(dma->channel);
    // Release DMA channel
    dma_release_channel(dma->channel->channel_p);
    printk(KERN_INFO "dmadc module exited\n");
}

static const struct of_device_id dmadc_of_ids[] = { {
                                                        .compatible =
                                                            "3j14,dmadc",
                                                    },
                                                    {} };

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

static int __init
dmadc_init(void)
{
    return platform_driver_register(&dmadc_driver);
}

static void __exit
dmadc_exit(void)
{
    platform_driver_unregister(&dmadc_driver);
}

module_init(dmadc_init);
module_exit(dmadc_exit);

MODULE_AUTHOR("Xilinx, Inc.");
MODULE_AUTHOR("Jonas Drotleff");
MODULE_DESCRIPTION("DMA ADC");
MODULE_LICENSE("GPL v2");
