LOCAL_PATH := $(call my-dir)

# Apps that are useless on a clock with no camera, modem or accounts, plus
# the serif CJK font (24 MB; CJK text falls back to NotoSansCJK).
# system is only 512 MiB, so they are dropped from the image.
include $(CLEAR_VARS)
LOCAL_MODULE := RemovePackages
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_TAGS := optional
LOCAL_OVERRIDES_PACKAGES := \
    Backgrounds \
    Camera2 \
    Contacts \
    Email \
    Exchange2 \
    Gallery2 \
    NotoSerifCJK-Regular.ttc \
    Traceur
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := /dev/null
include $(BUILD_PREBUILT)
