#!/bin/bash

build_type=("dtbs" "all" "modules" "image" "clean")

function usage()
{
    echo "Usage: build.sh [ dtbs | all | modules | image | clean ]"
    echo "Options:"
    echo "  dtbs  only build device-tree"
    echo "  modules  only build kernel_module"
    echo "  image  only build kernel image: uImage"
    echo "  all  build dtbs modules and uImage"
    echo "  clean  clean all the object files along with the executable"
}

function make_clean()
{
    runcmd "make mrproper"
    runcmd "make distclean"
    runcmd "rm -rf $BUILD_OUTPUT_PATH"
}
function make_dtbs()
{
    runcmd "make O=${BUILD_OUTPUT_PATH} dtbs -j${N}"
}
function make_uImage()
{
    runcmd "make O=${BUILD_OUTPUT_PATH} uImage LOADADDR=0XC2000040 -j${N}"
}
function make_modules()
{
    runcmd "make O=${BUILD_OUTPUT_PATH} modules -j${N}"
    runcmd "make O=${BUILD_OUTPUT_PATH} modules_install INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=${TARGET_MODULES_PATH} -j${N}"

    # echo "compressing kernel modules..."
    # runcmd "tar -jcvf ../../modules.tar.bz2 ${TARGET_MODULES_PATH}/lib/modules"
}

function make_all()
{
    runcmd "make O=${BUILD_OUTPUT_PATH} uImage dtbs LOADADDR=0XC2000040 vmlinux -j${N}"
    make_modules
}

cmd=$1
if [ "$#" != 0 ] && ( ! echo "${build_type[@]}" | grep -wq "$cmd" );then
    usage
    exit 1
fi
source envsetup.sh || {
    echo "envsetup.sh not exist"
}
export KERNEL_DEFCONFIG=stm32mp1_mmc_defconfig
echo "KERNEL_DEFCONFIG=$KERNEL_DEFCONFIG"
echo "BUILD_OUTPUT_PATH=$BUILD_OUTPUT_PATH"

#first create .config
runcmd "make O=${BUILD_OUTPUT_PATH} $KERNEL_DEFCONFIG -j${N}"

if [ x"$cmd" == x"clean" ];then
    echo "clean kernel workspace"
    make_clean
    exit 0
elif [ x"$cmd" == x"dtbs" ];then
    make_dtbs
elif [ x"$cmd" == x"image" ];then
    make_uImage
elif [ x"$cmd" == x"modules" ];then
    make_modules
else
    make_all
fi

# remove unnecessary directory
runcmd "rm -rf ${TARGET_MODULES_PATH}/lib/modules/5.4.31/source"
runcmd "rm -rf ${TARGET_MODULES_PATH}/lib/modules/5.4.31/build"
cpfiles ${BUILD_OUTPUT_PATH}/arch/arm/boot/uImage ${TARGET_BOOT_PATH}
cp ${BUILD_OUTPUT_PATH}/arch/arm/boot/dts/stm32mp157d-atk*.dtb ${TARGET_BOOT_PATH}

echo "******************************"
echo "       build OK !!!"
echo "******************************"
echo ">>File: uImage= `ls -lh ${TARGET_BOOT_PATH}/uImage | awk '{print $5}'`"