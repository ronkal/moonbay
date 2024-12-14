#!/usr/bin/env -S bash -e

# Cleaning the TTY.
clear

# Log file for debugging.
LOG_FILE="/var/log/moonbay.log"
exec > >(tee -a "$LOG_FILE") 2>&1

source ./scripts/cosmetics.sh
source ./scripts/disk_operations.sh
source ./scripts/networking.sh
source ./scripts/preferences.sh
source ./scripts/user_operations.sh
source ./scripts/vm.sh

# Installing audio drivers.
audio_installer() {
    info_print "Installing audio firmwares (pipewire, wireplumber, and pavucontrol)."
    pacstrap /mnt pipewire pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack pavucontrol wireplumber &>/dev/null
}

# Microcode detector.
microcode_detector() {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        microcode="amd-ucode"
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        microcode="intel-ucode"
    fi
}

# Welcome screen.
echo -ne "${BOLD}${BYELLOW}
================================================================
███╗   ███╗ ██████╗  ██████╗ ███╗   ██╗██████╗  █████╗ ██╗   ██╗
████╗ ████║██╔═══██╗██╔═══██╗████╗  ██║██╔══██╗██╔══██╗╚██╗ ██╔╝
██╔████╔██║██║   ██║██║   ██║██╔██╗ ██║██████╔╝███████║ ╚████╔╝ 
██║╚██╔╝██║██║   ██║██║   ██║██║╚██╗██║██╔══██╗██╔══██║  ╚██╔╝  
██║ ╚═╝ ██║╚██████╔╝╚██████╔╝██║ ╚████║██████╔╝██║  ██║   ██║   
╚═╝     ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝   ╚═╝   
================================================================
${RESET}"

info_print "Welcome to moonbay, a script made to simplify the process of installing Arch Linux."

# Detect Windows partitions
if blkid | grep -q 'ntfs'; then
    info_print "Windows installation detected."
    info_print "Would you like to set up for Dual Boot? (y/N)"
    read -r dualboot

    # If $dualboot is equal to "y"
    if [[ "${dualboot,,}" =~ ^(yes|y)$ ]]; then
        # Proceed with dual boot installation
        exit 0
    fi

    # If it's empty or is anything else, proceed with standalone installation.
fi

# [NOTE] This should be the OPTIONAL installation, not the default.
# Since this one wipes the entire disk, rather than a partition before continuing with normal procedure.
# For both methods (Dual Boot, and Standalone), the rest of the installation process is practically the same.

# STANDALONE INSTALLATION

# Choosing the target for the installation.
info_print "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "

select ENTRY in $(lsblk -dpnoNAME | grep -P "/dev/sd|nvme|vd"); do
    if [[ -n "$ENTRY" ]]; then
        DISK="$ENTRY"
        info_print "Arch Linux will be installed on the disk: $DISK"
        break
    else
        info_print "Invalid selection. Please try again."
    fi
done

# Double confirmation before disk wipe.
input_print "This will delete the current partition table on $DISK. Do you agree (y/N)?: "
read -r disk_response
if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Quitting."
    exit 1
fi

# Final confirmation for disk wipe.
input_print "This will delete all data on $DISK. Are you sure you want to continue (y/N)?: "
read -r final_confirmation
if ! [[ "${final_confirmation,,}" =~ ^(yes|y)$ ]]; then
    error_print "Disk wipe aborted."
    exit 1
fi

info_print "Wiping $DISK."
if ! wipefs -af "$DISK" &>/dev/null; then
    error_print "Failed to wipe disk. Exiting."
    exit 1
fi

if ! sgdisk -Zo "$DISK" &>/dev/null; then
    error_print "Failed to create new GPT partition table. Exiting."
    exit 1
fi

# Choosing locale.
until locale_selector; do :; done

# Choosing keyboard layout.
until kblayout_selector; do :; done

# Choosing kernel.
until kernel_selector; do :; done

# Setting up networking.
network_setup

# User choses the hostname.
until hostname_selector; do :; done

# Installing bluetooth
bluetooth_installer

# User sets up the user/root passwords.
until userpass_selector; do :; done
until rootpass_selector; do :; done

# Creating a new partition scheme.
info_print "Creating the partitions on $DISK."
if ! parted -s "$DISK" mklabel gpt \
    mkpart ESP fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart ARCH 1025MiB 100%; then
    error_print "Failed to create partitions. Exiting."
    exit 1
fi

ESP="/dev/disk/by-partlabel/ESP"
ARCH="/dev/disk/by-partlabel/ARCH"

# Informing the Kernel of the changes.
info_print "Informing the Kernel about the disk changes."
if ! partprobe "$DISK"; then
    error_print "Failed to inform kernel of disk changes. Exiting."
    exit 1
fi

# Formatting the ESP as FAT32.
info_print "Formatting the EFI Partition as FAT32."
if ! mkfs.fat -F 32 "$ESP" &>/dev/null; then
    error_print "Failed to format EFI Partition as FAT32. Exiting."
    exit 1
fi

# Formatting the ARCH as BTRFS.
info_print "Formatting the root partition as BTRFS."
if ! mkfs.btrfs -f "$ARCH" &>/dev/null; then
    error_print "Failed to format root partition as BTRFS. Exiting."
    exit 1
fi
mount "$ARCH" /mnt

# Creating BTRFS subvolumes.
info_print "Creating BTRFS subvolumes."
subvols=(snapshots var_pkgs var_log home)
for subvol in '' "${subvols[@]}"; do
    if ! btrfs su cr /mnt/@"$subvol" &>/dev/null; then
        error_print "Failed to create subvolume $subvol. Exiting."
        exit 1
    fi
done

# Mounting the newly created subvolumes.
umount /mnt
info_print "Mounting the newly created subvolumes."
mountopts="ssd,noatime,compress-force=zstd:3,discard=async"
if ! mount -o "$mountopts",subvol=@ "$ARCH" /mnt; then
    error_print "Failed to mount root subvolume. Exiting."
    exit 1
fi
mkdir -p /mnt/{home,.snapshots,var/{log,cache/pacman/pkg},efi}
for subvol in "${subvols[@]:2}"; do
    if ! mount -o "$mountopts",subvol=@"$subvol" "$ARCH" /mnt/"${subvol//_//}"; then
        error_print "Failed to mount subvolume $subvol. Exiting."
        exit 1
    fi
done
mount -o "$mountopts",subvol=@snapshots "$ARCH" /mnt/.snapshots
mount -o "$mountopts",subvol=@var_pkgs "$ARCH" /mnt/var/cache/pacman/pkg
chattr +C /mnt/var/log
if ! mount "$ESP" /mnt/efi/; then
    error_print "Failed to mount EFI partition. Exiting."
    exit 1
fi

# Checking the microcode to install.
microcode_detector

# Pacstrap (setting up a base sytem onto the new root).
info_print "Installing the base system (it may take a while)."
if ! pacstrap -K /mnt base base-devel "$kernel" "$microcode" linux-firmware "$kernel"-headers btrfs-progs grub grub-btrfs rsync efibootmgr reflector snapper snap-pac zram-generator sudo git nano zsh &>/dev/null; then
    error_print "Failed to install base system. Exiting."
    exit 1
fi

# Setting up the hostname.
echo "$hostname" >/mnt/etc/hostname

# Generating /etc/fstab.
info_print "Generating a new fstab."
if ! genfstab -U /mnt >>/mnt/etc/fstab; then
    error_print "Failed to generate fstab. Exiting."
    exit 1
fi

# Configure selected locale and console keymap
sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
echo "LANG=$locale" >/mnt/etc/locale.conf
echo "KEYMAP=$kblayout" >/mnt/etc/vconsole.conf

# Setting hosts file.
info_print "Setting hosts file."
cat >/mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

# Virtualization check.
virt_check

# Setting up the network.
network_installer
bluetooth_installer

# Setting up the audio.
audio_installer

# Configuring /etc/mkinitcpio.conf.
info_print "Configuring /etc/mkinitcpio.conf."
cat >/mnt/etc/mkinitcpio.conf <<EOF
HOOKS=(base udev systemd autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
EOF

# Configuring the system.
info_print "Configuring the system (timezone, system clock, initramfs, Snapper, PC Speaker, GRUB, mirrors)."
arch-chroot /mnt /bin/bash -e <<EOF

    # Setting up timezone.
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null

    # Setting up clock.
    hwclock --systohc

    # Generating locales.
    locale-gen &>/dev/null

    # Create SecureBoot keys. 
    # This isn't strictly necessary, linux-hardened preset expects it and mkinitcpio will fail without it
    # sbctl create-keys

    # Generating a new initramfs.
    mkinitcpio -P &>/dev/null

    # Snapper configuration.
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots &>/dev/null
    mkdir /.snapshots
    mount -a &>/dev/null
    chmod 750 /.snapshots

    # Disable PC Speaker
    echo -e "blacklist pcspkr\nblacklist snd_pcsp" > /etc/modprobe.d/nobeep.conf

    # Installing GRUB.
    grub-install --target=x86_64-efi --efi-directory=/efi/ --bootloader-id=GRUB &>/dev/null

    # Creating grub config file.
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null

    # Update mirrors
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    reflector -l 200 -f 30 -c "us," -p https -n 30 -a 48 --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null

    # Configure reflector.timer
    echo -e "--latest 200\n--fastest 30\n--country \"us,\"\n--protocol https\n--number 30\n--age 48\n--sort rate\n--save /etc/pacman.d/mirrorlist" > /etc/xdg/reflector/reflector.conf

EOF

# Setting root password.
info_print "Setting root password."
echo "root:$rootpass" | arch-chroot /mnt chpasswd

# Setting user password.
if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/wheel
    info_print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    info_print "Setting user password for $username."
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi

# Boot backup hook.
info_print "Configuring /boot backup when pacman transactions are made."
mkdir /mnt/etc/pacman.d/hooks
cat >/mnt/etc/pacman.d/hooks/50-bootbackup.hook <<EOF
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

# ZRAM configuration.
info_print "Configuring ZRAM."
cat >/mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
EOF

# Pacman eye-candy features.
info_print "Enabling colours, animations, and parallel downloads for pacman."
sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf

# Enabling various services.
info_print "Enabling Reflector, automatic snapshots, BTRFS scrubbing and systemd-oomd."
services=(reflector.timer snapper-timeline.timer snapper-cleanup.timer btrfs-scrub@-.timer btrfs-scrub@home.timer btrfs-scrub@var-log.timer btrfs-scrub@\\x2esnapshots.timer grub-btrfsd.service systemd-oomd)
for service in "${services[@]}"; do
    systemctl enable "$service" --root=/mnt &>/dev/null
done

# Final validation.
info_print "Performing final system validation..."
if ! grep -q "/" /mnt/etc/fstab; then
    error_print "Fstab seems incomplete. Please review."
fi

# Verify bootloader installation.
if ! arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi/ --bootloader-id=GRUB &>/dev/null; then
    error_print "Bootloader installation failed."
    exit 1
fi

# Finishing up.
info_print "Done, you may now wish to reboot (further changes can be done by chrooting into /mnt)."
exit
