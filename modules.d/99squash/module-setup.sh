#!/bin/bash

check() {
    return 255
}

depends() {
    # There should be no dependency for squash module to work
    # But switch-root when using squash is only tested with systemd
    echo "systemd systemd-initrd"
    return 0
}

installkernel() {
    _install_deps() {
        local _kmodule=$1
        local _depens=$(modinfo -F depends $_kmodule | tr "," " ")
        local _modfile=$(modinfo -n $_kmodule)
        local _instdest="/squash/preload-modules/$_kmodule.ko"

        if [ -n "$_depens" ]; then
            for _mod in $_depens; do
                _install_deps $_mod
            done
        fi

        # inst_simple_decompress will fail if it's not compressed
        inst_simple_decompress $_modfile $_instdest || inst_simple $_modfile $_instdest

        if [ $? -ne 0 ]; then
            derror "Failed to install and decompress kernel module."
            return 1
        fi
    }

    for _mod in squashfs loop overlay; do
        _install_deps $_mod
    done
}

install() {
    if ! type -P mksquashfs >/dev/null || ! type -P unsquashfs >/dev/null ; then
        derror "squash module requires squashfs-tools to be installed."
        return 1
    fi

    inst $dracutbasedir/squash-loader /squash/squash-loader
    inst $moddir/clear-squash.sh /squash/clear-squash.sh
}
