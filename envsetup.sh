#!/bin/bash
complete -F _buildsh_prompt build.sh
_buildsh_prompt()
{
    local cur prev opts  
    COMPREPLY=()  
    cur="${COMP_WORDS[COMP_CWORD]}"  
    prev="${COMP_WORDS[COMP_CWORD-1]}"  
    opts="dtbs all modules image clean"                                                                                                                                                                                

    if [[ ${cur} == * ]] ; then  
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )   
        return 0   
    fi 
}

function gettop
{
    local TOPFILE=envsetup.sh
    if [ -f $TOPFILE ] ; then
        PWD= /bin/pwd
    else
        local HERE=$PWD
        local T=
        while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
            \cd ..
            T=`PWD= /bin/pwd -P`
        done
        \cd $HERE
        if [ -f "$T/$TOPFILE" ]; then
            echo $T
        fi
    fi
}
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabihf-

export TOPDIR=$(gettop)
export N=$(( ($(cat /proc/cpuinfo |grep 'processor'|wc -l)) ))
export BUILD_OUTPUT_PATH=${TOPDIR}/out
export TARGET_MODULES_PATH=${BUILD_OUTPUT_PATH}/_modules
export TARGET_BOOT_PATH=${BUILD_OUTPUT_PATH}/_boot
export TARGET_BOOT_EXT4_PATH=${BUILD_OUTPUT_PATH}/_boot_ext4
export KERNEL_DEFCONFIG=stm32mp1_mmc_defconfig

echo "KERNEL_DEFCONFIG=$KERNEL_DEFCONFIG"
echo "BUILD_OUTPUT_PATH=$BUILD_OUTPUT_PATH"