#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/lenovo/cd24501f

# 1 GB RAM
$(call inherit-product, $(SRC_TARGET_DIR)/product/go_defaults.mk)

PRODUCT_SHIPPING_API_LEVEL := 27

# Screen: the panel is natively 480x800 portrait; stock rotates it to landscape
# in the window manager (rotation 1), and so do we (below).
# 240 dpi matches stock oem.prop; higher drops below Android's minimum size.
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := hdpi
TARGET_SCREEN_WIDTH := 480
TARGET_SCREEN_HEIGHT := 800
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=240

# Fixed landscape (rotation 1, like stock); see init.mt8167.rc
PRODUCT_PROPERTY_OVERRIDES += \
    persist.demo.rotationlock=true

DEVICE_PACKAGE_OVERLAYS += $(DEVICE_PATH)/overlay

# A/B
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

PRODUCT_PACKAGES += \
    android.hardware.boot@1.0-impl \
    android.hardware.boot@1.0-service \
    bootctrl.avb \
    otapreopt_script \
    update_engine \
    update_engine_sideload \
    update_verifier

PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.bootctrl=avb

# Static boot HAL for update_engine_sideload in recovery; it also provides the
# libcutils that the static sideload binary needs (set_cpuset_policy)
PRODUCT_STATIC_BOOT_CONTROL_HAL := \
    bootctrl.avb \
    libavb_user \
    libcutils \
    libfs_mgr

# Rootdir
# The board DTB has no early-mount fstab, so /vendor is only mounted by
# mount_all: everything init needs before that must live in the system root.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/fstab.mt8167:root/fstab.mt8167 \
    $(DEVICE_PATH)/rootdir/etc/init.mt8167.rc:root/init.mt8167.rc \
    $(DEVICE_PATH)/rootdir/etc/init.mt8167.usb.rc:root/init.mt8167.usb.rc \
    $(DEVICE_PATH)/rootdir/etc/init.connectivity.rc:root/init.connectivity.rc \
    $(DEVICE_PATH)/rootdir/etc/ueventd.mt8167.rc:root/ueventd.mt8167.rc \
    $(DEVICE_PATH)/rootdir/etc/init.recovery.mt8167.rc:root/init.recovery.mt8167.rc

# Audio
PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-impl \
    android.hardware.audio@2.0-service \
    android.hardware.audio.effect@2.0-impl \
    audio.a2dp.default \
    audio.r_submix.default \
    audio.usb.default \
    libaudio-resampler \
    libaudioroute \
    tinymix

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(DEVICE_PATH)/configs/audio/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    $(DEVICE_PATH)/configs/audio/audio_mapping.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_mapping.xml \
    $(DEVICE_PATH)/configs/audio/audio_effects.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.conf \
    $(DEVICE_PATH)/configs/audio/audio_platform_info.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_platform_info.xml \
    $(DEVICE_PATH)/configs/audio/mixer_paths_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_paths_0.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml

# Bluetooth
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/bluetooth/bt_did.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/bluetooth/bt_did.conf \
    $(DEVICE_PATH)/configs/bluetooth/bt_stack.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/bluetooth/bt_stack.conf

# Configstore
PRODUCT_PACKAGES += \
    android.hardware.configstore@1.0-service

# DRM
PRODUCT_PACKAGES += \
    android.hardware.drm@1.0-impl \
    android.hardware.drm@1.0-service

# Graphics (allocator/mapper/composer/EGL come from blobs)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.opengles.version=196610 \
    debug.hwui.use_buffer_age=false

# Keymaster: stock uses the Android Things-only vendor.google.iot.keymaster@3.1,
# so fall back to the software keymaster
PRODUCT_PACKAGES += \
    android.hardware.keymaster@3.0-impl \
    android.hardware.keymaster@3.0-service

# Media
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/media/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(DEVICE_PATH)/configs/media/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    $(DEVICE_PATH)/configs/media/media_codecs_google_video_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video_le.xml \
    $(DEVICE_PATH)/configs/media/media_codecs_mediatek_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_mediatek_video.xml \
    $(DEVICE_PATH)/configs/media/media_codecs_performance.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_performance.xml \
    $(DEVICE_PATH)/configs/media/mtk_omx_core.cfg:$(TARGET_COPY_OUT_VENDOR)/etc/mtk_omx_core.cfg

# Permissions (no telephony, no camera, no battery)
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    $(DEVICE_PATH)/configs/permissions/android.hardware.microphone.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.microphone.xml \
    frameworks/native/data/etc/android.hardware.screen.landscape.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.screen.landscape.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.distinct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.distinct.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/tablet_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/tablet_core_hardware.xml

# Memtrack (wraps the memtrack.mt8167 blob). The manifest declares it as
# hwbinder, so without the service system_server blocks forever in
# IMemtrack::getService() while starting ActivityManager.
PRODUCT_PACKAGES += \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service

# Speaker amp, mic ADC, volume keys and mute slider: on stock these were
# driven by the Android Things OEM app (see smartclockd/)
PRODUCT_PACKAGES += \
    smartclockd

# Size: drop apps with no use on this device (see removed-packages/)
PRODUCT_PACKAGES += \
    RemovePackages

# USB
PRODUCT_PACKAGES += \
    android.hardware.usb@1.0-service.basic

# Wi-Fi
PRODUCT_PACKAGES += \
    libshim_wifi \
    hostapd \
    libwpa_client \
    wificond \
    wpa_supplicant

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/wifi/android.hardware.wifi@1.0-service.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/android.hardware.wifi@1.0-service.rc \
    $(DEVICE_PATH)/configs/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    $(DEVICE_PATH)/configs/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf \
    $(DEVICE_PATH)/configs/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf

PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0 \
    ro.boot.wificountrycode=US

# Debugging during bring-up
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=adb

# ro.adb.secure=1 comes from main.mk via default.prop (read first, so it
# wins), and there's no screen to accept the prompt during bring-up: trust the
# build host's adb key. Copy ~/.android/adbkey.pub to adb_keys (not committed).
ifneq ($(wildcard $(DEVICE_PATH)/adb_keys),)
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/adb_keys:root/adb_keys
endif

# Inherit the proprietary files
$(call inherit-product-if-exists, vendor/lenovo/cd24501f/cd24501f-vendor.mk)
