#!/bin/bash
KERNEL_IMAGE=../kernel/arch/arm64/boot/Image
PRIVATE_MODULE_DIR=./ramdisk/lib/modules
PRIVATE_LOAD_FILE=./ramdisk_modules.load
TEMP_MODULES_PATH=./temp/lib/modules/0.0
KERNEL_DRIVERS_PATH=../kernel/drivers
if [ ! -n "$1" ]; then
  DTB_PATH=../kernel/arch/arm64/boot/dts/rockchip/rk3399-evb-ind-lpddr4-android-avb.dtb
else    
  DTB_PATH=../kernel/arch/arm64/boot/dts/rockchip/$1.dtb
fi

export PATH=$PATH:./bin

echo "==========================================="
echo -e "\033[33mYou can create ramdisk_modules.load here to customize modules.load\033[0m"
echo -e "\033[33mUse DTS as $DTB_PATH\033[0m"
echo "==========================================="
echo "Preparing temp dirs and use placeholder 0.0..."
if [ -d temp ]; then
  rm -rf temp
fi
if [ -d $PRIVATE_MODULE_DIR ]; then
  rm -rf $PRIVATE_MODULE_DIR
fi
if [ -d out ]; then
  rm -rf out
fi
if [ ! -d system ]; then
  mkdir system
fi
if [ ! -d ramdisk/dev ]; then
  mkdir -p ramdisk/dev
fi
if [ ! -d ramdisk/mnt ]; then
  mkdir -p ramdisk/mnt
fi
if [ ! -d ramdisk/sys ]; then
  mkdir -p ramdisk/sys
fi
if [ ! -d ramdisk/proc ]; then
  mkdir -p ramdisk/proc
fi
if [ ! -d ramdisk/debug_ramdisk ]; then
  mkdir -p ramdisk/debug_ramdisk
fi
mkdir -p out
mkdir -p $TEMP_MODULES_PATH
mkdir -p $PRIVATE_MODULE_DIR
echo "Prepare temp dirs done."
echo "==========================================="
modules_array=($(find $KERNEL_DRIVERS_PATH -type f -name *.ko))
for MODULE in "${modules_array[@]}"
do
  echo "Copying $MODULE..."
  cp $MODULE $TEMP_MODULES_PATH/
  cp $MODULE $PRIVATE_MODULE_DIR/
done
echo "==========================================="
echo "Generating depmod..."
depmod -b temp 0.0
find $TEMP_MODULES_PATH -type f -name *.ko | xargs basename -a > $TEMP_MODULES_PATH/modules.load
cp $TEMP_MODULES_PATH/modules.load ./modules_scan_result.load
echo -e "\033[32mSave modules scan result as ./modules_scan_result.load \033[0m"
echo "Generate depmod done."

cp $TEMP_MODULES_PATH/modules.alias $PRIVATE_MODULE_DIR/
if [ ! -f $PRIVATE_LOAD_FILE ]; then
  cp $TEMP_MODULES_PATH/modules.load $PRIVATE_MODULE_DIR/
else
  echo -e "\033[32mUse specific $PRIVATE_LOAD_FILE as modules.load \033[0m"
  cp $PRIVATE_LOAD_FILE $PRIVATE_MODULE_DIR/modules.load
fi
cp $TEMP_MODULES_PATH/modules.dep $PRIVATE_MODULE_DIR/
cp $TEMP_MODULES_PATH/modules.softdep $PRIVATE_MODULE_DIR/

echo "==========================================="
echo "making ramdisk..."
mkbootfs -d ./system ./ramdisk | minigzip > out/ramdisk.img
echo "make ramdisk done."

echo "==========================================="
echo "making boot image..."
mkbootimg  --kernel $KERNEL_IMAGE --ramdisk out/ramdisk.img --dtb $DTB_PATH --cmdline "console=ttyFIQ0 androidboot.baseband=N/A androidboot.wificountrycode=US androidboot.veritymode=enforcing androidboot.hardware=rk30board androidboot.console=ttyFIQ0 androidboot.verifiedbootstate=orange firmware_class.path=/vendor/etc/firmware init=/init rootwait ro loop.max_part=7 androidboot.first_stage_console=1 androidboot.selinux=permissive buildvariant=userdebug" --os_version 11 --os_patch_level 2020-06-05 --second ../kernel/resource.img --header_version 2 --output out/boot.img 
echo "make boot image done."
echo "==========================================="
