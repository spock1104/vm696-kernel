#!/bin/bash

#default toolchain to use
KERNEL_SDK=`pwd`/../prebuilt

# I keep the toolchains in a different place
HOSTNAME=$(hostname)

case "$HOSTNAME" in
"laptop")
  KERNEL_SDK="/home/j/android/.sdks/kernelToolchain/prebuilt"
  ;;
"media-pc")
  KERNEL_SDK="/home/j/android-sdks/kernel_sdk/prebuilt"
  ;;
esac


KS=$(pwd)/scripts
CC=${KERNEL_SDK}/linux-x86/toolchain/arm-eabi-4.4.3/bin
CC1=${KERNEL_SDK}/linux-x86/toolchain/arm-eabi-4.4.3/prebuilt/linux-x86/libexec/gcc/arm-eabi/4.4.3
export PATH=${KS}:${CC}:${CC1}:$PATH
export TARGET_PRODUCT=m3s_virgin_us

mkdir -p out
make lge_m3s-perf_defconfig ARCH=arm CROSS_COMPILE=${CC}/arm-eabi- O=out -j2
if [ "$?" -ne "0" ]; then
  echo "make defconfig failed"
  exit 1
fi

# build it
make ARCH=arm CROSS_COMPILE=${CC}/arm-eabi- O=out -j2
if [ "$?" -ne "0" ]; then
  echo "Build failed"
  exit 1
fi

# check for abootimg
if [ -z `which abootimg` ]; then
  echo "abootimg not found in PATH; not packing boot image"
  exit 0
fi

# pack up a boot image
IMG_OUT="boot_"`date +%m_%d_%H_%M`".img"
[ -f ${IMG_OUT} ] && rm "$IMG_OUT"
cp "vm696_zv5_stock_boot.img" ${IMG_OUT} || exit 1
abootimg -u ${IMG_OUT} -k "out/arch/arm/boot/zImage" || exit 1

# write update-script 
cat << EOF > "androidInstallableZip/META-INF/com/google/android/updater-script"
assert( getprop("ro.product.device") == "m3s_virgin_us" );
ui_print("");
ui_print( "Installing `date +%m/%d/%Y_%H:%M` custom giantpune boot.img ..." );
show_progress(1.0,0);
set_progress(0.33);
package_extract_file( "${IMG_OUT}", "/dev/block/mmcblk0p9" );
set_progress(0.66);
set_progress(1.00);
ui_print("Done !");
EOF

# copy boot.img into the zip folder
cp "${IMG_OUT}" "androidInstallableZip/${IMG_OUT}" || exit 1

# zip it up
ZIP_OUT="lgoe_pernel_"`date +%m_%d_%H_%M`".zip"
cd androidInstallableZip
zip -r ../"${ZIP_OUT}" *
cd ..
rm "androidInstallableZip/${IMG_OUT}"
rm "androidInstallableZip/META-INF/com/google/android/updater-script"
echo "Installable zip created: "${ZIP_OUT}