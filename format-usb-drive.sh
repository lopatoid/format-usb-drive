#!/bin/bash

if [ $EUID != 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

devs="$(find /dev/disk/by-path | grep -- '-usb-' | grep -v -- '-part[0-9]*$' || true)"
devs="$(readlink -f $devs)"

if [ -z "$devs" ]; then
	echo "error: no usb device found"
	exit 2
fi

i=0
for dialogdev in $devs; do
	i=$((i+1))
	dialogmodel="$(lsblk -ndo model "$dialogdev")"
	size=$(lsblk -n -r -o size "$dialogdev" | head -n1)
	echo $i '|' "$dialogdev" '|' "$dialogmodel" '|' "$size" 
done
devarr=($devs)

echo "Select drive to format (all data on this disk will be lost):" && read x
if [ -z "$x" ]; then
	echo no drive selected
	exit 2
fi
x=$((x-1))
dev="${devarr[$x]}"
label=$(lsblk -ndo model "$dev")
size=$(lsblk -n -r -o size "$dev" | head -n1)
echo "$dev" "$label $size" selected
umount "$dev"?

echo "1 fat32"
echo "2 ntfs"
grep -q exfat /proc/filesystems
if [ $? -eq 0 ]; then
	echo "3 exfat"
fi
echo "Select filesystem" && read fs

if [ "$fs" == "3" ] && ! [ -x "$(command -v mkfs.exfat)" ]; then
	echo "mkfs.exfat could not be found, please install exfatprogs"
	exit 2
fi

if [ "$1" == "--erase" ]; then
	dd if=/dev/zero of="$dev" bs=4096 status=progress
else
	dd if=/dev/zero of="$dev" bs=1M count=1
fi
sync

if [ "$fs" == "1" ]; then
	parted --align optimal "$dev" mklabel msdos mkpart primary fat32 0% 100%
	sync && partprobe "$dev" && sleep 1
	fat32name=`echo $size | tr ., __`
	mkfs.fat -F 32 -n "$fat32name"  "$dev"1
fi
if [ "$fs" == "2" ]; then
	parted --align optimal "$dev" mklabel msdos mkpart primary ntfs 0% 100%
	sync && partprobe "$dev" && sleep 1
	mkfs.ntfs --fast --no-indexing -L "$label $size" "$dev"1
fi
if [ "$fs" == "3" ]; then
	parted --align optimal "$dev" mklabel msdos mkpart primary ntfs 0% 100%
	sync && partprobe "$dev" && sleep 1
	mkfs.exfat -L "$size" "$dev"1
fi
sync
