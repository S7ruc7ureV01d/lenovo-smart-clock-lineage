#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/lenovo/cd24501f

# Partition sizes come from the device itself (fastboot getvar all)
-include $(DEVICE_PATH)/BoardConfigPartitions.mk
ifeq ($(BOARD_SYSTEMIMAGE_PARTITION_SIZE),)
$(error Create $(DEVICE_PATH)/BoardConfigPartitions.mk from BoardConfigPartitions.mk.example first)
endif

# Architecture: arm64 kernel, 32-bit-only userspace (same as stock)
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
# Cortex-A35; Pie has no a35 tuning, a53 is the closest supported variant
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_SMP := true

# The arm64 kernel speaks the 64-bit binder protocol (no
# CONFIG_ANDROID_BINDER_IPC_32BIT); without this every service aborts with
# "Binder driver could not be opened"
TARGET_USES_64_BIT_BINDER := true

# Platform
TARGET_BOARD_PLATFORM := mt8167
TARGET_BOOTLOADER_BOARD_NAME := mt8516
TARGET_NO_BOOTLOADER := true
BOARD_HAS_MTK_HARDWARE := true

# Kernel
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x14f88000
BOARD_KERNEL_TAGS_OFFSET := 0x0df88000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
BOARD_MKBOOTIMG_ARGS := \
    --kernel_offset $(BOARD_KERNEL_OFFSET) \
    --ramdisk_offset $(BOARD_RAMDISK_OFFSET) \
    --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
# Stock appends the reference-board DTBs to the kernel, but LK ignores them:
# it loads the board DTB from oem_bootloader_<slot> (dt_table, identical to
# /oem/kernel.dtb). Never overwrite oem_bootloader_* or oem_*.
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_CROSS_COMPILE_PREFIX := aarch64-linux-android-
# Userspace is 32-bit, so the build only puts the arm toolchain on PATH
KERNEL_TOOLCHAIN := $(shell pwd)/prebuilts/gcc/$(HOST_OS)-x86/aarch64/aarch64-linux-android-4.9/bin
TARGET_KERNEL_SOURCE := kernel/lenovo/mt8167s
TARGET_KERNEL_CONFIG := cd24501f_defconfig

# Set to true to boot the stock kernel while the source build is untested
TARGET_USE_PREBUILT_KERNEL ?= false
ifeq ($(TARGET_USE_PREBUILT_KERNEL),true)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image.gz-dtb
endif

# A/B, system-as-root, recovery in the boot ramdisk
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := boot system vendor
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true
BOARD_USES_RECOVERY_AS_BOOT := true
TARGET_NO_RECOVERY := true

# Filesystems
BOARD_FLASH_BLOCK_SIZE := 131072
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.mt8167

# AVB: LK rejects the slot (and resets it to unbootable) unless vbmeta looks
# like stock: rollback index 1 (stock's stored index), flags 0, and descriptors
# for oem_bootloader, oem and factory, which LK verifies too. Those come from
# stock vbmeta_b (stockdesc.py), so this vbmeta is for slot B. Unlocked LK
# accepts the test key and hash mismatches (orange state), like Magisk boot.
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := 1
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --include_descriptors_from_image $(DEVICE_PATH)/prebuilt/vbmeta_stock_slot_b.img

# Not Treble: blobs are Android 8.1 non-VNDK
PRODUCT_FULL_TREBLE_OVERRIDE := false
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml

# Graphics (PowerVR GE8300, HWC1 via libhwc2on1adapter blob)
USE_OPENGL_RENDERER := true
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3
TARGET_RUNNING_WITHOUT_SYNC_FRAMEWORK := false
BOARD_EGL_CFG :=

# Audio
USE_XML_AUDIO_POLICY_CONF := 1

# Bluetooth (MT7668 combo)
BOARD_HAVE_BLUETOOTH := true

# Wi-Fi (MT7668 gen4 driver, built in; powered via /dev/wmtWifi)
# No BOARD_WLAN_DEVICE: the Wi-Fi HAL service and libwifi-hal are stock blobs,
# and "MediaTek" would make the source libwifi-hal want libwifi-hal-mt66xx,
# which is not in the tree.
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211
WIFI_DRIVER_FW_PATH_PARAM := "/dev/wmtWifi"
WIFI_DRIVER_FW_PATH_STA := STA
WIFI_DRIVER_FW_PATH_AP := AP
WIFI_DRIVER_FW_PATH_P2P := P2P

# Shims for 8.1 blobs on Pie (see shims/)
TARGET_LD_SHIM_LIBS := \
    /vendor/bin/hw/android.hardware.wifi@1.0-service|libshim_wifi.so

# Low RAM / 32-bit
MALLOC_SVELTE := true

# system is only 512 MiB (stock uses 415 MiB of it): don't preopt to save space
WITH_DEXPREOPT ?= false
DONT_DEXPREOPT_PREBUILTS := true

# SELinux (permissive for bring-up)
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy
SELINUX_IGNORE_NEVERALLOWS := true

# Inherit the proprietary files
-include vendor/lenovo/cd24501f/BoardConfigVendor.mk
