#include <linux/types.h>
#include <linux/kernel.h>
#include <linux/delay.h>
#include <linux/ide.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/errno.h>
#include <linux/gpio.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/of_gpio.h>
#include <linux/semaphore.h>
#include <linux/timer.h>
#include <linux/irq.h>
#include <linux/wait.h>
#include <linux/poll.h>
#include <linux/fs.h>
#include <linux/fcntl.h>
#include <linux/platform_device.h>
#include <asm/mach/map.h>
#include <asm/uaccess.h>
#include <asm/io.h>
#include <linux/device.h>
#include <linux/irq.h>
#include <linux/of_irq.h>

#define KET_CNT 1
#define KEY_NAME "key"
enum key_status {
	KEY_PRESS = 0,
	KEY_RELASE,
	KEY_KEEP,
};
struct key_dev_t {
	int status;
	dev_t devid;
	struct cdev cdev; /* cdev */
	struct class *class; /* 类 */
	struct device *device; /* 设备 */
	struct device_node *nd; /* 设备节点 */
	int key_gpio; /* key 所使用的 GPIO 编号*/
	struct timer_list timer; /* 按键值 */
	int irq_num; /* 中断号 */
	spinlock_t spinlock; /* 自旋锁 */
};

static int key_open(struct inode *inode, struct file *filp)
{
	struct key_dev_t *key_dev;
	key_dev = container_of(inode->i_cdev, struct key_dev_t, cdev);
	printk("key open!\n");
	return 0;
}
static int key_release(struct inode *inode, struct file *filp)
{

	return 0;
}
static ssize_t key_write(struct file *filp, const char __user *buf,size_t cnt,loff_t *offt)
{
	return 0;
}
static ssize_t key_read(struct file *filp, char __user *buf,size_t cnt,loff_t *offt)
{
	unsigned long flags;
	int ret;
	struct key_dev_t *key_dev;
	struct cdev *cdev = filp->f_path.dentry->d_inode->i_cdev;
	key_dev = container_of(cdev, struct key_dev_t, cdev);
	spin_lock_irqsave(&key_dev->spinlock, flags);

	ret = copy_to_user(buf, &key_dev->status, sizeof(key_dev->status));
	spin_unlock_irqrestore(&key_dev->spinlock, flags);
	return ret;
}
static struct file_operations key_fops = {
	.owner = THIS_MODULE,
	.open = key_open,
	.write = key_write,
	.read = key_read,
	.release = key_release,
};
static irqreturn_t key_interrupt_isr(int irq, void *data)
{
	struct key_dev_t *key_dev = (struct key_dev_t *)data;
	printk(KERN_ERR "key_interrupt_isr!!!\n");
	if(gpio_get_value(key_dev->key_gpio))
		key_dev->status = KEY_PRESS;
	else
		key_dev->status = KEY_RELASE;
	return IRQ_HANDLED;
}
static int key_gpio_init(struct device_node *nd, struct key_dev_t *dev)
{
	int ret;
	u32 irq_flags;
	struct key_dev_t *key_dev = dev;
	key_dev->key_gpio = of_get_named_gpio(nd, "key-gpio", 0);
	if (key_dev->key_gpio < 0) {
		printk("cannot get key gpio\n");
		return -EINVAL;
    }
    key_dev->irq_num = irq_of_parse_and_map(nd, 0);
    if(!key_dev->irq_num)
	    return -EINVAL;
    printk("key_dev->key_gpio=%d,irq=%d\n", key_dev->key_gpio, key_dev->irq_num);

    ret = gpio_request(key_dev->key_gpio, "KEY0");
    if (ret) {
	    printk(KERN_ERR "failed to gpio_request,ret=%d\n", ret);
	    return -EINVAL;
    }
    gpio_direction_input(key_dev->key_gpio);
    irq_flags = irq_get_trigger_type(key_dev->irq_num);
    if(irq_flags == IRQF_TRIGGER_NONE){
	    printk("irq_flags = IRQF_TRIGGER_NONE\n");
	    return -EINVAL;
    }

    ret = request_irq(key_dev->irq_num, key_interrupt_isr, irq_flags,
		      "KEY0_IRQ", key_dev);

    return 0;
}
static int key_probe(struct platform_device *pdev)
{
	int ret;
	struct key_dev_t *key_dev;
	printk("key driver and device was matched!\r\n");
	key_dev = kzalloc(sizeof(*key_dev), GFP_KERNEL);

	spin_lock_init(&key_dev->spinlock);
	/* 初始化 LED */
	ret = key_gpio_init(pdev->dev.of_node, key_dev);
	if (ret < 0)
		return ret;
		
	/* 1、设置设备号 */
	ret = alloc_chrdev_region(&key_dev->devid, 0, KET_CNT, KEY_NAME);
	if(ret < 0) {
		pr_err("%s Couldn't alloc_chrdev_region, ret=%d\r\n", KEY_NAME, ret);
	}
	
	/* 2、初始化cdev  */
	key_dev->cdev.owner = THIS_MODULE;
	cdev_init(&key_dev->cdev, &key_fops);
	
	/* 3、添加一个cdev */
	ret = cdev_add(&key_dev->cdev, key_dev->devid, KET_CNT);
	if(ret < 0)
		goto del_unregister;
	
	/* 4、创建类      */
	key_dev->class = class_create(THIS_MODULE, KEY_NAME);
	if (IS_ERR(key_dev->class)) {
		goto del_cdev;
	}

	/* 5、创建设备 */
	key_dev->device = device_create(key_dev->class, NULL, key_dev->devid, NULL, KEY_NAME);
	if (IS_ERR(key_dev->device)) {
		goto destroy_class;
	}
	platform_set_drvdata(pdev, key_dev);
	return 0;
destroy_class:
	class_destroy(key_dev->class);
del_cdev:
	cdev_del(&key_dev->cdev);
del_unregister:
	unregister_chrdev_region(key_dev->devid, KET_CNT);
	kfree(key_dev);
	return -EIO;
}

static int key_remove(struct platform_device *pdev)
{
	struct key_dev_t *key_dev;

	key_dev = platform_get_drvdata(pdev);
	printk(KERN_ERR "key module remove!\n");
	gpio_free(key_dev->key_gpio);	/*释放gpio*/
	free_irq(key_dev->irq_num,NULL);
	cdev_del(&key_dev->cdev); /*  删除cdev */
	unregister_chrdev_region(key_dev->devid, KET_CNT); /* 注销设备号 */
	device_destroy(key_dev->class, key_dev->devid);	/* 注销设备 */
	class_destroy(key_dev->class); /* 注销类 */
	kfree(key_dev);
	return 0;
}
static const struct of_device_id key_of_match[] = {
	{ .compatible = "alientek,key" },
	{ /* Sentinel */ }
};
MODULE_DEVICE_TABLE(of, key_of_match);
static struct platform_driver key_driver = {
	.driver		= {
		.name	= "key_drive_name",			/* 驱动名字，用于和设备匹配 */
		.of_match_table	= key_of_match, /* 设备树匹配表 		 */
	},
	.probe		= key_probe,
	.remove		= key_remove,
};
module_platform_driver(key_driver);
MODULE_LICENSE("GPL");