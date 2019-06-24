#!/bin/bash

# called by dracut
check() {
    if dracut_module_included iscsi; then
        return 0
    fi
    return 1
}

# called by dracut
depends() {
    echo iscsi network
}

# called by dracut
cmdline() {
    setup_iscsi_network() {
        local dev_path session_path connection_path
        local iscsi_conn iscsi_address
        local local_address ifname ifmac bootproto

        [[ -L "/sys/dev/block/$1" ]] || return

        dev_path=$(cd -P /sys/dev/block/$1; echo $PWD)
        session_path=${iscsi_path%%/target*}
        [ "$session_path" = "$dev_path" ] && return 1

        for connection_path in ${session_path}/*connection* ; do
            iscsi_conn=${connection_path##*/}
            conn=${connection_path}/iscsi_connection/${iscsi_conn}
            if [ -d ${conn} ] ; then
                iscsi_address=$(cat ${conn}/persistent_address)
            fi
        done

        [ -z "$iscsi_address" ] && return 1

        local_address=$(ip -o route get to $iscsi_address | sed -n 's/.*src \([0-9a-f.:]*\).*/\1/p')
        ifname=$(ip -o route get to $iscsi_address | sed -n 's/.*dev \([^ ]*\).*/\1/p')
        bootproto=$(sed -n "s/BOOTPROTO='\?\([[:alpha:]]*6\?\)4\?/\1/p" /etc/sysconfig/network-scripts/ifcfg-$ifname)
        if [ $bootproto ]; then
            printf 'ip=%s:%s ' ${ifname} ${bootproto}
        else
            printf 'ip=%s:none ' ${ifname}
        fi

        if [ -e /sys/class/net/$ifname/address ] ; then
            ifmac=$(cat /sys/class/net/$ifname/address)
            printf 'ifname=%s:%s ' ${ifname} ${ifmac}
        fi
    }

    for_each_host_dev_and_slaves_all setup_iscsi_network
}

# called by dracut
install() {
    local iscsi_network_cmdline

    if [[ $hostonly_cmdline == "yes" ]] ; then
        iscsi_network_cmdline=$(cmdline)
        [[ $iscsi_network_cmdline ]] && printf "%s\n" "$iscsi_network_cmdline" >> "${initdir}/etc/cmdline.d/96iscsi-network.conf"
    fi
}
