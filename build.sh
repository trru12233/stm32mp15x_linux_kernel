#!/bin/bash

cmd=$1
source envsetup.sh || exit 1
echo "KERNEL_DEFCONFIG=$KERNEL_DEFCONFIG"
echo "BUILD_OUTPUT_PATH=$BUILD_OUTPUT_PATH"

function clean()
{
    runcmd "make mrproper"
    runcmd "make distclean"
    runcmd "rm -rf $BUILD_OUTPUT_PATH"
}

if [ x"$cmd" == x"clean" ];then
    echo "clean kernel workspace"
    clean
    exit 0
elif [ x"$cmd" == x"dtb" ];then
    echo "just make device-tree"
    runcmd "make  O=${BUILD_OUTPUT_PATH} dtbs LOADADDR=0XC2000040 vmlinux -j${N}"
    exit 0
fi

make O=${BUILD_OUTPUT_PATH} $KERNEL_DEFCONFIG -j${N} || {
        echo "make $KERNEL_DEFCONFIG failed"
        exit 1
    }

# make kernel and dtbs
make  O=${BUILD_OUTPUT_PATH} uImage dtbs LOADADDR=0XC2000040 vmlinux -j${N} || {
        echo "make modules_install to INSTALL_MOD_PATH for release ko failed"
        exit 1
    }

# make modules_install to INSTALL_MOD_PATH release ko
make O=${BUILD_OUTPUT_PATH} modules -j${N} || {
        echo "make modules failed"
        exit 1
    }
make O=${BUILD_OUTPUT_PATH} modules_install INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=${TARGET_MODULES_PATH} -j${N} || {
        echo "make modules_install failed"
        exit 1
    }
# remove unnecessary directory
runcmd "rm -rf ${TARGET_MODULES_PATH}/lib/modules/5.4.31/source"
runcmd "rm -rf ${TARGET_MODULES_PATH}/lib/modules/5.4.31/build"

#裁剪模块的调试信息
# runcmd "find ${TARGET_MODULES_PATH} -name "*.ko" | xargs $STRIP --strip-debug --remove-section=.comment --remove-section=.note --preserve-dates"

cd ${TARGET_MODULES_PATH}/lib/modules
runcmd "tar -jcvf ../../modules.tar.bz2 ."
cd -

#copy uImage and dtb
cpfiles ${BUILD_OUTPUT_PATH}/arch/arm/boot/uImage ${TARGET_BOOT_PATH}
cp ${BUILD_OUTPUT_PATH}/arch/arm/boot/dts/stm32mp157d-atk*.dtb ${TARGET_BOOT_PATH}
echo "******************************"
echo "       build OK !!!"
echo "******************************"
echo ">>File: uImage= `ls -lh ${TARGET_BOOT_PATH}/uImage | awk '{print $5}'`"