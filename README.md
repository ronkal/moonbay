![](https://img.shields.io/github/license/ronkal/moonbay?label=License)

![](https://img.shields.io/github/stars/ronkal/moonbay?label=Stars)

![](https://img.shields.io/github/forks/ronkal/moonbay?label=Forks)

[moonbay](https://github.com/ronkal/moonbay) is a **bash script** that bootstraps [Arch Linux](https://archlinux.org/) with sane and useful defaults.

- **BTRFS snapshots**: you will have a resilient setup that automatically takes snapshots of your volumes based on a weekly schedule
- **ZRAM**: the setup use ZRAM which aims to replace traditional swap partition/files by making the system snappier
- **systemd-oomd**: systemd-oomd will take care of OOM situations at userspace level rather than at kernel level, making the system less prone to kernel crashes
- **VM additions**: the script automatically provides guest tools if it detects that a virtualized environment such as VMWare Workstation, VirtualBox, QEMU-KVM is being used
- **User account setup**: a default user account with sudo permissions can be configured in order to avoid hassle in the post installation phase

# One-step Automated Install (shorter)

```bash

bash <(curl -fsSL https://raw.githubusercontent.com/ronkal/moonbay/main/moonbay.sh)

```

# Alternative Methods (manual)

```bash

curl -fsSLo moonbay.sh https://raw.githubusercontent.com/ronkal/moonbay/main/moonbay.sh \

chmod +x moonbay.sh \

bash moonbay.sh

```

# Partitions Layout

The **partitions layout** is simple and it consists of three partitions:

1. A **FAT32** partition (512MiB), mounted at `/efi/` as ESP.
2. An **ARCH** partition mounted at `/` as root directory.
3. A **HOME** partition mounted at `/home/` as home directory.

| Partition Number | Label | Size             | Mountpoint | Filesystem |
| ---------------- | ----- | ---------------- | ---------- | ---------- |
| 1                | ESP   | 512 MiB          | /efi/      | FAT32      |
| 2                | ARCH  | 40 GiB           | /          | BTRFS      |
| 3                | HOME  | Rest of the disk | /home/     | BTRFS      |

# BTRFS Subvolumes Layout

The **BTRFS subvolumes layout** follows the traditional and suggested layout used by **Snapper**, you can find it [here](https://wiki.archlinux.org/index.php/Snapper#Suggested_filesystem_layout).

| Subvolume Number | Subvolume Name | Mountpoint  |
| ---------------- | -------------- | ----------- |
| 1                | @              | /           |
| 2                | @home          | /home       |
| 3                | @snapshots     | /.snapshots |
| 4                | @var_log       | /var/log    |

# Special Thanks

- [classy-giraffe/easy-arch](https://github.com/classy-giraffe/easy-arch) installation script.
