#!/bin/sh
#
# unpack, modify and re-pack the Xiaomi R3600 firmware
# removes checks for release channel before starting dropbear
#
# 2020.07.20  darell tan
# 

set -e

IMG=$1
ROOTPW='$1$qtLLI4cm$c0v3yxzYPI46s28rbAYG//'  # "password"

[ -e "$IMG" ] || { echo "rootfs img not found $IMG"; exit 1; }

# verify programs exist
command -v unsquashfs &>/dev/null || { echo "install unsquashfs"; exit 1; }
mksquashfs -version >/dev/null || { echo "install mksquashfs"; exit 1; }

FSDIR=`mktemp -d /tmp/resquash-rootfs.XXXXX`
trap "rm -rf $FSDIR" EXIT

# test mknod privileges
mknod "$FSDIR/foo" c 0 0 2>/dev/null || { echo "need to be run with fakeroot"; exit 1; }
rm -f "$FSDIR/foo"

>&2 echo "unpacking squashfs..."
unsquashfs -f -d "$FSDIR" "$IMG"

>&2 echo "patching squashfs..."

# modify dropbear init
sed -i 's/channel=.*/channel=release2/' "$FSDIR/etc/init.d/dropbear"

# make sure our backdoors are always enabled by default
sed -i '/ssh_en=/d; /uart_en=/d; /boot_wait=/d;' "$FSDIR/usr/share/xiaoqiang/xiaoqiang-defaults.txt"
cat <<XQDEF >> "$FSDIR/usr/share/xiaoqiang/xiaoqiang-defaults.txt"
uart_en=1
ssh_en=1
boot_wait=on
XQDEF

# modify root password
sed -i "s@root:[^:]*@root:${ROOTPW}@" "$FSDIR/etc/shadow"

# dont start crap services
for SVC in stat_points statisticsservice \
		datacenter \
		smartcontroller \
		plugincenter plugin_start_script.sh cp_preinstall_plugins.sh; do
	rm -f $FSDIR/etc/rc.d/[SK]*$SVC
done

# prevent stats phone home & auto-update
for f in StatPoints mtd_crash_log logupload.lua otapredownload; do > $FSDIR/usr/sbin/$f; done

# cron jobs are mostly non-OpenWRT stuff
for f in $FSDIR/etc/crontabs/*; do
	sed -i 's/^/#/' $f
done

# as a last-ditch effort, change the *.miwifi.com hostnames to localhost
sed -i 's@\w\+.miwifi.com@localhost@g' $FSDIR/etc/config/miwifi

>&2 echo "repacking squashfs..."
rm -f "$IMG.new"
mksquashfs "$FSDIR" "$IMG.new" -comp xz -b 256K -no-xattrs

