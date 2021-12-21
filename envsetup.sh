#!/bin/bash

function runcmd()
{
    if [ $# -ne 1 ];then
        echo "Usage: runcmd command_string"
        exit 1
    fi
    echo "$1"
    $1 || {
        echo "failed"
        exit 1
    }
}
function cpfiles()
{
    if [ $# -ne 2 ];then
        echo "Usage: cpfiles \"sourcefiles\" \"destdir\""
        exit 1
    fi

    mkdir -p $2 || {
        echo "mkdir -p $2 failed"
        exit 1
    }

    for f in $1
    do
        if [ -a $f ];then
            cp -af $f $2 || {
                echo "cp -af $f $2 failed"
                exit 1
            }
        fi
    done
    echo "cpfiles $1 $2"
}
export N=$(( ($(cat /proc/cpuinfo |grep 'processor'|wc -l)) ))
export BUILD_OUTPUT_PATH=$(pwd)/out
export TARGET_MODULES_PATH=${BUILD_OUTPUT_PATH}/_modules
export TARGET_BOOT_PATH=${BUILD_OUTPUT_PATH}/_boot
export TARGET_BOOT_EXT4_PATH=${BUILD_OUTPUT_PATH}/_boot_ext4
export KERNEL_DEFCONFIG=stm32mp1_mmc_defconfig
