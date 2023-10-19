#!/bin/bash

build_type=("dtbs" "all" "modules" "image" "clean")
INFODIVIDER="\
###############################################################################\
";
. envsetup.sh || exit 1
start_log

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
    echo $INFODIVIDER
    echo "# make dtb"
    echo $INFODIVIDER
    runcmd "rm -r ${BUILD_OUTPUT_PATH}/arch/arm/boot/dts/"
    runcmd "make O=${BUILD_OUTPUT_PATH} dtbs -j${N}"
    runcmd "cp ${BUILD_OUTPUT_PATH}/arch/arm/boot/dts/*.dtb ${TARGET_BOOT_PATH}"
    runcmd "dtc -I dtb -O dts ${TARGET_BOOT_PATH}/stm32mp157d-atk.dtb > ${TARGET_BOOT_PATH}/source_atk.dts"
}

function make_uImage()
{
    echo $INFODIVIDER
    echo "# make uImage"
    echo $INFODIVIDER
    runcmd "make O=${BUILD_OUTPUT_PATH} uImage LOADADDR=0XC2000040 -j${N}"
    cpfiles ${BUILD_OUTPUT_PATH}/arch/arm/boot/uImage ${TARGET_BOOT_PATH}
}

function make_modules()
{
    echo $INFODIVIDER
    echo "# make kernel modules"
    echo $INFODIVIDER
    runcmd "make O=${BUILD_OUTPUT_PATH} modules -j${N}"
    runcmd "make O=${BUILD_OUTPUT_PATH} modules_install INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=${TARGET_MODULES_PATH} -j${N}"

    # remove unnecessary directory
    runcmd "rm -rf ${TARGET_MODULES_PATH}/lib/modules/5.4.31/source"
    runcmd "rm -rf ${TARGET_MODULES_PATH}/lib/modules/5.4.31/build"
    cp -r ${TARGET_MODULES_PATH}/lib/modules/5.4.31/
    # echo "compressing kernel modules..."
    # runcmd "tar -jcvf ../../modules.tar.bz2 ${TARGET_MODULES_PATH}/lib/modules"
}

function make_all()
{
    runcmd "make O=${BUILD_OUTPUT_PATH} uImage dtbs LOADADDR=0XC2000040 vmlinux -j${N}"
    cpfiles ${BUILD_OUTPUT_PATH}/arch/arm/boot/uImage ${TARGET_BOOT_PATH}
    runcmd "cp ${BUILD_OUTPUT_PATH}/arch/arm/boot/dts/*.dtb ${TARGET_BOOT_PATH}"

    make_modules
}
function package_bootfs()
{
    echo $INFODIVIDER
    echo "# Start package uImage and device-trees to bootfs.ext4"
    echo $INFODIVIDER

    rm -r ${TARGET_BOOT_EXT4_PATH}
    mkdir ${TARGET_BOOT_EXT4_PATH}
    cp ${TARGET_BOOT_PATH}/*.dtb ${TARGET_BOOT_EXT4_PATH}
    cp ${TARGET_BOOT_PATH}/uImage ${TARGET_BOOT_EXT4_PATH}
    cp -r lcd_bmp/* ${TARGET_BOOT_EXT4_PATH}
    cp -r ${TARGET_MODULES_PATH}/lib/modules/* ${TARGET_BOOT_EXT4_PATH}
    runcmd "make_ext4fs -L bootfs -l 67108864 ${TARGET_BOOT_EXT4_PATH}/bootfs.ext4 ${TARGET_BOOT_EXT4_PATH}"
    echo "Create ext4 Filesystem Success"
    echo "${TARGET_BOOT_EXT4_PATH}/bootfs.ext4 = `ls -lh ${TARGET_BOOT_EXT4_PATH}/bootfs.ext4 | awk '{print $5}'`"
}

cmd=$1
if [ "$#" != 0 ] && ( ! echo "${build_type[@]}" | grep -wq "$cmd" );then
    usage
    exit 1
fi
[ -n "$BUILD_OUTPUT_PATH" ] || {
    echo "Please source envsetup.sh first"
    exit 1
}
if [ x"$cmd" == x"clean" ];then
    echo "clean kernel workspace"
    make_clean
    exit 0
fi

#first create .config
runcmd "make O=${BUILD_OUTPUT_PATH} $KERNEL_DEFCONFIG -j${N}"
rm -r ${TARGET_BOOT_PATH}
mkdir ${TARGET_BOOT_PATH}

if [ x"$cmd" == x"dtbs" ];then
    echo "===========make dtbs==============="
    make_dtbs
elif [ x"$cmd" == x"image" ];then
    echo "===========make kernel uImage==============="
    make_uImage
elif [ x"$cmd" == x"modules" ];then
    echo "===========make kernel modules==============="
    make_modules
else
    make_all
    package_bootfs
fi


echo $INFODIVIDER
echo "# Build OK !!!"
echo $INFODIVIDER
echo ">>File: uImage= `ls -lh ${TARGET_BOOT_PATH}/uImage | awk '{print $5}'`"