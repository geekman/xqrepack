#!/bin/sh
#
# repacks the kernel & rootfs image into a UBI image
#
# 2020.07.20  darell tan
#

set -e

KERNEL=$1
ROOTFS=$2
OUTPUT=r3600-raw-img.bin

# check for ubinize
ubinize -V >/dev/null || { echo "need ubinize, from mtd-utils maybe?"; exit 1; }

[ -f "$KERNEL" ] || { echo "kernel img doesnt exist."; exit 1; }
[ -f "$ROOTFS" ] || { echo "rootfs doesnt exist."; exit 1; }

# verify files
ROOTFS_SIG=`hexdump -n 4 -e '"%_p"' "$ROOTFS"`
[ "$ROOTFS_SIG" = "hsqs" ] || { echo "rootfs is not squashfs."; exit 1; }

KERNEL_SIG=`hexdump -n 4 -e '1/1 "%02x"' "$KERNEL"`
[ "$KERNEL_SIG" = "d00dfeed" ] || { echo "invalid kernel img"; exit 1; }

UBICFG=`mktemp /tmp/r3600-ubicfg.XXXXX`
trap "rm -f $UBICFG" EXIT

cat <<CFGEND > $UBICFG
[kernel]
mode=ubi
image=$KERNEL
vol_id=0
vol_type=dynamic
vol_name=kernel

[rootfs]
mode=ubi
image=$ROOTFS
vol_id=1
vol_type=dynamic
vol_name=ubi_rootfs
CFGEND

ubinize -m 2048 -p 128KiB -o "$OUTPUT" "$UBICFG"

echo "done."

