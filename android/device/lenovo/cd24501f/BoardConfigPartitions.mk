# Read from the device (/proc/partitions, CD-24501F, 2026-10-27)
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432      # 32 MiB, boot_a/boot_b
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 536870912   # 512 MiB, system_a/system_b
BOARD_VENDORIMAGE_PARTITION_SIZE := 67108864    # 64 MiB, vendor_a/vendor_b

# ~2300 files on system; the default (one inode per 4 KiB block) wastes
# ~31 MB of the 512 MiB partition on inode tables
BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT := 8192
