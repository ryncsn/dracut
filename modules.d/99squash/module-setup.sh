#!/bin/bash

check() {
    return 255
}

depends() {
    return 0
}

installkernel() {
    hostonly="" hostonly_strict="" instmods squashfs loop
}

install() {
    inst modprobe
    inst ${moddir}/init.squash.sh /init.squash
}
