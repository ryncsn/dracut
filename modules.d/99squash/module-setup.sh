#!/bin/bash

check() {
    return 255
}

depends() {
    return 0
}

installkernel() {
    hostonly="" instmods squashfs loop
}

install() {
    inst modprobe
    inst ${moddir}/init.squash.sh /init.squash
}
