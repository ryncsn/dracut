#!/bin/sh
PATH=/bin:/sbin

SQUASH_IMG=/init.squash.img
SQUASH_MNT=/squash/root
SQUASHED_MNT="usr etc"

# Following mount points are neccessary for mounting a squash image

[ ! -d /proc/self ] && \
	mount -t proc -o nosuid,noexec,nodev proc /proc

[ ! -d /sys/kernel ] && \
	mount -t sysfs -o nosuid,noexec,nodev sysfs /sys

mount -t devtmpfs -o mode=0755,noexec,nosuid,strictatime devtmpfs /dev

# Need a loop device backend, and squashfs module
modprobe loop
if [ $? != 0 ]; then
    echo "Unable to setup loop module"
fi

modprobe squashfs
if [ $? != 0 ]; then
    echo "Unable to setup squashfs module"
fi

modprobe overlay
if [ $? != 0 ]; then
    echo "Unable to setup overlay module"
fi

[ -d $SQUASH_MNT ] || \
	mkdir -m 0755 -p $SQUASH_MNT

mount -t squashfs -o ro,loop $SQUASH_IMG $SQUASH_MNT

# Mount and replace
if [ $? != 0 ]; then
    echo "Unable to mount squashed initramfs image"
fi

# Create a bind mount of old root so symlinks inside squash image
# can resolve
for file in $SQUASHED_MNT; do
	lowerdir=$SQUASH_MNT/$file
	upperdir=/$file
	mntdir=/$file
	workdir=/overlay/work/$file

	mkdir -m 0755 -p $workdir
	mkdir -m 0755 -p /$file

	mount -t overlay overlay -o\
		lowerdir=$lowerdir,upperdir=$upperdir,workdir=$workdir $mntdir
done
