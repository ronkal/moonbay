#!/usr/bin/env -S bash -e

# Virtualization check.
virt_check() {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
    kvm)
        info_print "KVM has been detected, setting up guest tools."
        pacstrap /mnt qemu-guest-agent &>/dev/null
        systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
        ;;
    vmware)
        info_print "VMWare Workstation/ESXi has been detected, setting up guest tools."
        pacstrap /mnt open-vm-tools >/dev/null
        systemctl enable vmtoolsd --root=/mnt &>/dev/null
        systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
        ;;
    oracle)
        info_print "VirtualBox has been detected, setting up guest tools."
        pacstrap /mnt virtualbox-guest-utils &>/dev/null
        systemctl enable vboxservice --root=/mnt &>/dev/null
        ;;
    microsoft)
        info_print "Hyper-V has been detected, setting up guest tools."
        pacstrap /mnt hyperv &>/dev/null
        systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
        systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
        systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
        ;;
    esac
}
