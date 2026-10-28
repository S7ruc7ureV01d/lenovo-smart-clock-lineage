#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# 32-bit only: inherit full_base, not core_64_bit
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Wi-Fi only, no telephony
$(call inherit-product, vendor/lineage/config/common_mini_tablet_wifionly.mk)

$(call inherit-product, device/lenovo/cd24501f/device.mk)

# The locale list also filters APK resources: with all ~90 languages from
# languages_full.mk, system doesn't fit in 512 MiB. Add locales here if needed.
PRODUCT_LOCALES := en_US

PRODUCT_NAME := lineage_cd24501f
PRODUCT_DEVICE := cd24501f
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Lenovo Smart Clock
PRODUCT_MANUFACTURER := LENOVO

PRODUCT_GMS_CLIENTID_BASE := android-lenovo

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=CD-24501F \
    PRIVATE_BUILD_DESC="iot_mt8167s_som-user 8.1.0 OIM6.190107.007.A5 5341849 release-keys"

BUILD_FINGERPRINT := Things/iot_mt8167s_som/mt8167s_som:8.1.0/OIM6.190107.007.A5/5341849:user/release-keys
