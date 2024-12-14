#!/usr/bin/env -S bash -e

network_setup() {
    info_print "Installing and enabling NetworkManager."
    pacstrap /mnt networkmanager >/dev/null
    systemctl enable NetworkManager --root=/mnt &>/dev/null

    # Validate network connection
    info_print "Validating network connection..."
    if ! arch-chroot /mnt ping -c 1 archlinux.org &>/dev/null; then
        error_print "Network connection is not working. Please check your network settings."
        exit 1
    fi
}

# Set up hostname.
hostname_selector() {
    while true; do
        input_print "Please enter a hostname for your machine: "
        read -r hostname
        if [[ -z "$hostname" ]]; then
            error_print "You need to enter a hostname in order to continue."
        else
            break
        fi
    done
    return 0
}

# Installing bluetooth support.
bluetooth_installer() {
    info_print "Installing bluetooth (enable it after installation)."
    pacstrap /mnt bluez bluez-utils &>/dev/null
}
