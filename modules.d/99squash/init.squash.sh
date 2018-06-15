#!/bin/sh
PATH=/bin:/sbin
squash_dir=/dev/.squashed-initramfs

# Following mount points are neccessary for mounting a squash image
mount -t proc -o nosuid,noexec,nodev proc /proc >/dev/null
mount -t sysfs -o nosuid,noexec,nodev sysfs /sys >/dev/null
mount -t devtmpfs -o mode=0755,noexec,nosuid,strictatime devtmpfs /dev >/dev/null

# Need a loop device backend, and squashfs module
modprobe loop
if [[ $? != 0 ]]; then
    echo "Unable to setup loop device"
    exit 1
fi

modprobe squashfs
if [[ $? != 0 ]]; then
    echo "Unable to setup squashfs"
    exit 1
fi

mkdir -m 0755 -p ${squash_dir}
mount -t squashfs -o ro,loop /squash.img $squash_dir

# Mount and replace
if [[ $? != 0 ]]; then
    echo "Unable to mount squashed initramfs image"
    exit 1
fi

# Close all fds before exec
fd_path=/proc/self/fd
for fd in ${fd_path}/*; do
    fd=${fd#${fd_path}/}
    eval "exec ${fd}>&-"
done

ln -nsf ${squash_dir}/usr /usr
ln -nsf ${squash_dir}/etc /etc

exec /init.orig

echo "Something went wrong when trying to start the squashed init"
exit 1
