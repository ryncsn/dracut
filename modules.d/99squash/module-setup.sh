#!/bin/bash

check() {
    return 255
}

depends() {
    echo "bash"
    return 0
}

installkernel() {
    hostonly="" instmods squashfs loop overlay
}

install() {
	type -P mksquashfs >/dev/null || return 1
	type -P unsquashfs >/dev/null || return 1

    inst_multiple kmod modprobe mount mkdir ln echo
    inst ${moddir}/setup-squash.sh /squash/setup-squash.sh
    inst ${moddir}/init.sh /squash/init.sh
}
