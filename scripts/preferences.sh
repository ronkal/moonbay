#!/usr/bin/env -S bash -e

# Selecting a kernel to install.
kernel_selector() {
    while true; do
        info_print "List of kernels:"
        info_print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied"
        info_print "2) Longterm: Long-term support (LTS) Linux kernel"
        info_print "3) Zen Kernel: A Linux kernel optimized for desktop usage"
        input_print "Please select the number of the corresponding kernel (e.g. 1): "
        read -r kernel_choice
        case $kernel_choice in
        1)
            kernel="linux"
            break
            ;;
        2)
            kernel="linux-lts"
            break
            ;;
        3)
            kernel="linux-zen"
            break
            ;;
        *)
            error_print "You did not enter a valid selection, please try again."
            ;;
        esac
    done
}

# User chooses the locale.
locale_selector() {
    while true; do
        input_print "Please insert the locale you use (format: xx_XX. Enter empty to use en_US, or \"/\" to search locales): "
        read -r locale
        case "$locale" in
        '')
            locale="en_US.UTF-8"
            info_print "$locale will be the default locale."
            return 0
            ;;
        '/')
            sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
            clear
            ;;
        *)
            if grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<<"$locale") " /etc/locale.gen; then
                return 0
            else
                error_print "The specified locale doesn't exist or isn't supported."
            fi
            ;;
        esac
    done
}

# User chooses the console keyboard layout.
kblayout_selector() {
    while true; do
        input_print "Please insert the keyboard layout you'd like to use (enter empty to use US, or \"/\" to look up for keyboard layouts): "
        read -r kblayout
        case "$kblayout" in
        '')
            kblayout="us"
            info_print "The standard US keyboard layout will be used."
            return 0
            ;;
        '/')
            localectl list-keymaps
            clear
            ;;
        *)
            if localectl list-keymaps | grep -Fxq "$kblayout"; then
                info_print "Changing console layout to $kblayout."
                loadkeys "$kblayout"
                return 0
            else
                error_print "The specified keymap doesn't exist."
            fi
            ;;
        esac
    done
}
