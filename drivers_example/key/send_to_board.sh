#!/bin/bash

# 这个脚本的运行前提是能够ping通板子的ip

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

# runcmd "scp ${TARGET_BOOT_PATH}/*.dtb root@192.168.1.11:/run/media/mmcblk2p2/"
runcmd "scp *.ko root@192.168.1.11:/home/root/"
runcmd "scp app root@192.168.1.11:/home/root/"