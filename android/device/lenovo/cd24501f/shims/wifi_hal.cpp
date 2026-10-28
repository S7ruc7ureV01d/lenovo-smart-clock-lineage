/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

// The 8.1 Wi-Fi HAL service blob calls toString(sp<IWifiChipEventCallback>),
// which Pie's hidl-gen emits only as a static inline in the header. Provide
// the out-of-line symbol. The real header isn't included: its inline
// definition would clash with this one.

#include <string>

#include <utils/StrongPointer.h>

namespace android {
namespace hardware {
namespace wifi {
namespace V1_0 {

class IWifiChipEventCallback;

std::string toString(const ::android::sp<IWifiChipEventCallback>& o) {
    return "[IWifiChipEventCallback]" + std::to_string(reinterpret_cast<uintptr_t>(o.get()));
}

}  // namespace V1_0
}  // namespace wifi
}  // namespace hardware
}  // namespace android
