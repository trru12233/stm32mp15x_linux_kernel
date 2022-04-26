KERNELDIR := $(BUILD_OUTPUT_PATH)
CURRENT_PATH := $(shell pwd)

obj-m := key.o

build: kernel_modules

kernel_modules:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) modules -j${N}
	$(CROSS_COMPILE)gcc app.c -o app
	rm *.mod*
	rm *.o
clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURRENT_PATH) clean
