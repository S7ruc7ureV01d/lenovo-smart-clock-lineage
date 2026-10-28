# Lenovo Smart Clock (CD-24501F): LineageOS port findings

Last updated: 2026-10-27

Sources analysed:
- Stock dump: `src/dump` (github.com/deadman96385/things_mt8167s_som_dump)
- Kernel: `src/kernel` (github.com/deadman96385/android_kernel_lenovo_mt8167s)

## Verdict

A port is **feasible (about 7/10)**. Nothing blocks it outright: the kernel source matches the shipped
kernel, every board driver is in the tree, and the vendor blobs are all in the dump. The work is in
running an old 32-bit Android Things / 8.1 vendor on a newer Android.

**Target: LineageOS 16.0 (Android 9).** Use 15.1 only as a fallback for bring-up if 8.1 → 9 blob
breakage gets in the way. 17.1 is a stretch goal; avoid 18.1 and newer.

## Hardware

| Component | Detail | Evidence |
|---|---|---|
| SoC | MediaTek MT8167S, 4× Cortex-A35 | `ro.board.platform=mt8167`, `CONFIG_NR_CPUS=4` |
| RAM | 1 GB | `/oem/kernel.dtb` `memory@0`: `reg = <0 0x40000000 0 0x40000000>` |
| GPU | PowerVR GE8300 (Rogue, DDK "1.9ED") | `rgx.fw.signed.22.40.54.30`, `CONFIG_MTK_GPU_VERSION="rgx clark 1.9ED"` |
| PMIC | MT6392 | DTB `mediatek,mt6392` |
| Display | 800×480, DSI/LCM; stock density 240 (oem.prop) | `ro.sf.lcd_density=240` in `/oem/oem.prop` |
| Touch | FocalTech FT6336U @ i2c0 0x38 (Holitech + KD firmware) | DTB `mediatek,FT6336`, `vendor/firmware/FT6336U_*.bin` |
| Backlight | SGM37603A @ i2c2 0x36, LED class `lcd-backlight` | DTB, `drivers/leds/leds-sgm37603a.c` |
| Audio | TAS5782M amp + TLV320 ADC (mics), machine driver `mt8167s-som.c` | `sound/soc/codecs/tas5782m.c`, DTB pinctrl |
| Wi-Fi/BT | MT7668 combo over SDIO, built-in gen4 driver | `CONFIG_MTK_COMBO_CHIP_MT7668=y` |
| Sensors | ALS/PS node (`mediatek,als_ps`) | DTB; stock had no real sensors HAL |
| Storage | eMMC at `soc/11120000.mmc` | fstab |
| Not present | Camera, modem, battery | |

## Live device (adb, 2026-10-27)

Raw output is in `device-info/`. Stock slot `_a` is running with Magisk root, AVB `unlocked`/`orange`.

| Item | Value |
|---|---|
| eMMC | 7.3 GiB (`mmcblk0` 7634944 KiB) |
| RAM visible to Linux | 979 MiB (`MemTotal` 1002972 kB), no swap |
| SoC string | `MT8167A` (LK sets the DT model) |
| Display | Panel **480×800 portrait**, 56.79 Hz, 240 dpi. Stock rotates it to 800×480 landscape in the WM (rotation 1) |
| Touch | input `mtk-tpd`, i2c `0-0038` = `FT6336` |
| Backlight | i2c `2-0036` = `sgm37603a-led`, max 255 |
| Keys | input `mtk-pmic-keys` |
| Sound | one card `mtsndcard`, PCMs 0p/1c/2c/3c/4p/5c/6p |
| Wi-Fi | MT7668 gen4 driver working on stock (connected, RSSI −37) |
| Root/boot | `skip_initramfs root=/dev/dm-0`; LK builds the system dm-verity line (`dm="1 vroot …"`) from vbmeta |

### Partition map

| Partition | Size | Partition | Size |
|---|---|---|---|
| proinfo | 3 MiB | boot_a / boot_b | 32 MiB each |
| nvram | 5 MiB | **system_a / system_b** | **512 MiB each** |
| misc | 1 MiB | vbmeta_a / vbmeta_b | 64 KiB each |
| kb / dkb | 2 MiB each | vendor_a / vendor_b | 64 MiB each |
| seccfg | 256 KiB | oem_bootloader_a / _b | 4 MiB each |
| para | 512 KiB | factory | 32 MiB |
| frp | 1 MiB | factory_bootloader | 16 MiB |
| metadata | 32 MiB | oem_a / oem_b | 500 MiB each |
| logo | 8 MiB | userdata | 5.0 GiB |
| lk_a / lk_b | 384 KiB each | tee_a / tee_b | 5 MiB each |

### What the live device answered

- **Board DTB source:** `oem_bootloader_<slot>` holds an Android `dt_table` (magic `d7b7ab1e`) whose
  single entry is byte-identical to `/oem/kernel.dtb`, and the running FDT is that DTB plus LK's
  memory/chosen patches. LK almost certainly loads it from there and ignores the DTB appended to the kernel.
  Changing the DT therefore means flashing `oem_bootloader_*` (built with `mkdtimg`), not `boot`.
- **system is only 512 MiB.** Stock already uses 415 MiB. LineageOS 16.0 will be tight, so the tree
  turns dexpreopt off and keeps the package set small. Check the image size after the first build.
  Fallbacks if it doesn't fit: drop apps, or (risky) repartition.
- **vendor is 64 MiB** (stock uses 45 MiB). That's enough for the blobs plus source-built HALs.

### Backup

`backup/` contains a dd image of every partition **except `userdata`**, with sha256 checked against
the device for each image or chunk (`backup/SHA256SUMS`, 2.3 GB). It includes the device-unique
`factory`, `nvram`, `proinfo`, `seccfg`, `kb`/`dkb`, `frp` and both slots of lk/tee/boot/vbmeta/vendor/oem/system.
It also has `mmcblk0boot0.img` (the preloader, `EMMC_BOOT`/`FILE_INFO` header) and `mmcblk0boot1.img` (all zeros).
Note: `force_ro` is already `0` on both boot areas, so nothing stops a bad write to the preloader.
Never flash `preloader` from a random firmware.

Keep this folder private: it holds per-device keys and identifiers.

## Software (stock)

- Android Things 1.1 on Android 8.1.0 (API 27), build `OIM6.190107.007.A5`, security patch 2019-02-05
- Kernel **4.4.95**, arm64, built 2019-02-28. The source Makefile is 4.4.95 as well.
- **32-bit-only userspace**: `ro.product.cpu.abilist=armeabi-v7a,armeabi`, `bootopt=64S3,32N2,64N2`
- **Not Treble**: `ro.treble.enabled=false`, no VNDK. GSIs are not an option.
- **A/B + system-as-root**: `ro.build.ab_update=true`, `ro.build.system_root_image=true`.
  The boot ramdisk *is* recovery.
- AVB on system/vendor/oem (`avb` flags in fstab)
- Boot image: base `0x40078000`, kernel off `0x8000`, ramdisk off `0x14f88000`, tags off
  `0x0df88000`, page size 2048, kernel = `Image.gz` + 1 appended DTB.

## Things that are easy to get wrong

1. **There are two DTBs.** The DTB appended to the kernel in `boot.img` is MediaTek's *generic reference*
   board: it lists a GT9157 touchscreen and a camera, neither of which the clock has. The **real board DTB is
   `/oem/kernel.dtb`** (FT6336, SGM37603A, MT7668), and LK loads it from `oem_bootloader_<slot>`
   (confirmed on the live device, see below). **Never overwrite `oem_*` or `oem_bootloader_*`.**
2. **No early-mount fstab in the DTB.** The `android,firmware/fstab` node is empty, so `/vendor` is
   mounted only by `mount_all`. The init rc, fstab and ueventd files therefore have to live in the system
   root, not on `/vendor`.
3. **`wmt_loader` depends on Android Things.** The binary that powers up Wi-Fi/BT links
   `libsomconfig.so` (Things SoM config, which reads `/oem/somconfig/configuration.pb` and in turn needs
   libchrome and protobuf-full). It uses only `SomConfiguration::LoadConfiguration`,
   `SomConfigEntry::{GetChild,GetName,GetStringValue}` and property `ro.oem.product.wifi_module`, so a
   small shim can replace it if the 8.1 lib won't load on 9.
4. **Keymaster is Things-only** (`vendor.google.iot.keymaster@3.1`). Use the software keymaster 3.0.
5. **Sensors**: `sensors.iot.so` is the Things user-driver bridge, so no ALS HAL exists yet and auto-brightness is off.
6. **`libvp9dec_sa.ca7.so` needs `libmmprofile.so`**, which stock never shipped. It's excluded.
7. **Blobs sensitive to the libgui/libui ABI**: `hwcomposer.mt8167.so`, `libMtkOmx*`, `libstagefrighthw.so`.
   These are the most likely to need shims on Pie.
8. **Density**: 800×480 at 240 dpi = 533×320 dp, the smallest usable layout. Don't go higher.
9. **Recovery risk**: according to the unlock guide, the factory firmware on slot A can't be restored once
   it's gone. Dump every partition before you flash anything.

## Version choice

| Version | Notes |
|---|---|
| 15.1 (8.1) | Exact match for the blobs. Use only for bring-up. |
| **16.0 (9)** | **Recommended.** Non-Treble still supported, 4.4 fine, 8.1 blobs workable with shims. |
| 17.1 (10) | Possible later. Non-Treble is being phased out and the GPU blobs are a bigger risk. |
| 18.1+ | Not worth it: non-Treble, 1 GB, 32-bit, 2019 PowerVR blobs, kernel 4.4. |

## Device tree (`device/lenovo/cd24501f`)

Scaffolded for LineageOS 16.0 (lunch target `lineage_cd24501f-userdebug`).

| Decision | Why |
|---|---|
| `TARGET_ARCH := arm`, kernel `arm64` | Matches stock 32-bit userspace on a 64-bit kernel |
| `TARGET_CPU_VARIANT := cortex-a53` | Pie has no A35 tuning |
| Inherit `full_base` + `common_full_tablet_wifionly` + `go_defaults` | 32-bit, no telephony, 1 GB RAM |
| A/B, `BOARD_BUILD_SYSTEM_ROOT_IMAGE`, `BOARD_USES_RECOVERY_AS_BOOT` | Same layout as stock |
| vbmeta `--flags 3`, `avb` dropped from fstab | Device is AVB-unlocked; skip verification during bring-up |
| SELinux permissive via cmdline | Bring-up; real policy comes later |
| `TARGET_USE_PREBUILT_KERNEL=true` option (`prebuilt/Image.gz-dtb` = stock) | Get userspace up before trusting the source kernel |
| `cd24501f_defconfig` = stock `/proc/config.gz` | Copied into `src/kernel/arch/arm64/configs/` |
| Partition sizes in `BoardConfigPartitions.mk` | Read from the device: boot 32 MiB, system 512 MiB, vendor 64 MiB |
| `WITH_DEXPREOPT ?= false` | system is only 512 MiB |
| Boot animation size 480×800 | Panel is natively portrait |
| Blobs: MTK/PowerVR/MT7668/OMX/nvram/thermal from stock | 86 entries, all resolve against the dump |
| From source: audio/drm/boot/configstore/usb HAL services, wpa_supplicant, hostapd, keymaster (soft) | Generic AOSP code, avoids ABI drift |
| zram at 50% | 1 GB RAM; stock had none |

Extract blobs from the dump:

```sh
cd device/lenovo/cd24501f
STAGE=$(./stage-dump.sh /path/to/things_mt8167s_som_dump)
./extract-files.sh "$STAGE"
```

## Open questions / TODO

- [x] Partition sizes → `BoardConfigPartitions.mk` (from `/proc/partitions`)
- [x] Full partition backup except userdata (`backup/`)
- [x] Which DTB LK passes → the board DTB from `oem_bootloader_<slot>`
- [x] Preloader backup: `backup/mmcblk0boot0.img` (`EMMC_BOOT` header, MT8167 preloader); `boot1` is empty
- [ ] Landscape: try `ro.sf.hwrotation=90` (check touch mapping), or set `user_rotation=1` like stock does
- [ ] Measure `system.img` against the 512 MiB limit
- [ ] Verify Lineage 16 has `android.hardware.usb@1.0-service.basic`; otherwise switch to `android.hardware.usb@1.0-service`
- [ ] Boot with prebuilt kernel → get adb → `logcat`/`dmesg`
- [ ] Build kernel from source with Lineage's toolchain and compare behaviour
- [ ] Shims for hwcomposer/OMX if they fail with missing symbols
- [ ] `libsomconfig` shim if the stock lib won't load
- [ ] ALS sensors HAL (sysfs) → re-enable auto-brightness
- [ ] Real SELinux policy, then enforcing

## Build host requirements

| Item | Size |
|---|---|
| Device tree (this repo) | ~8 MB (incl. 7.6 MB prebuilt kernel) |
| LineageOS 16.0 source, full history | ~100 GB |
| LineageOS 16.0 source, `repo init --depth=1` + `repo sync -c` | ~50 GB |
| `out/` for one 32-bit device | ~50–70 GB |
| ccache (optional) | 25–50 GB |
| **Recommended free space** | **≥ 200 GB** (minimum ~120 GB shallow, no ccache) |

The host now has **~152 GB free**: enough for a shallow sync plus one build. Skip ccache, or cap it at ~20 GB (`ccache -M 20G`).

Pie's build system expects an older toolchain environment (python2, ncurses5, `LC_ALL=C` for flex).
On Arch, build inside an Ubuntu 18.04 container (distrobox/docker). 16+ GB RAM is fine (host has 30 GB).

## First successful build (2026-10-27)

`lineage-16.0-20261028-UNOFFICIAL-cd24501f.zip` (lineage_cd24501f-userdebug), kernel built from source
with aarch64 GCC 4.9. Not yet flashed or booted.

| Image | Size | Partition |
|---|---|---|
| boot.img | 32 MiB (14 MiB used, AVB footer) | boot_x 32 MiB |
| system.img | 478 MB of files in 512 MiB ext4 | system_x 512 MiB |
| vendor.img | 51 MB | vendor_x 64 MiB |
| vbmeta.img | 4 KiB, flags 3 (verification disabled) | vbmeta_x |

boot.img header addresses (kernel 0x40080000, ramdisk 0x55000000, tags 0x4e000000, page 2048) match stock.

Fitting system into 512 MiB required:
- `common_mini_tablet_wifionly` instead of `common_full_*` (no extra LatinIME dictionaries, ~45 MB)
- `PRODUCT_LOCALES := en_US` (PRODUCT_LOCALES is prepended to the aapt filter, so setting only
  PRODUCT_AAPT_CONFIG does nothing; ~110 MB)
- `removed-packages/`: Backgrounds, Camera2, Contacts, Email, Exchange2, Gallery2, Traceur, NotoSerifCJK
- `BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT := 8192` (~2300 files; default inode tables waste ~31 MB)

Build fixes along the way: KERNEL_TOOLCHAIN for the arm64 kernel on a 32-bit target; duplicate
`/dev/pvrsrvkm` in file_contexts; `PRODUCT_STATIC_BOOT_CONTROL_HAL` for update_engine_sideload.
More room later: use the other slot's oem/system partition as /product (gives up the stock fallback slot).

## Flashing and first boot (2026-10-27)

- **fastboot freezes:** LK answers only if the command is already waiting when fastboot enumerates
  (`fastboot set_active a` typed first, then plug in). Idle LK fastboot stops reading USB; every
  `fastboot flash` hangs before sending (host fastboot 37 queries). Use the adb route instead.
- **Flashing from stock (Magisk root):** push 64 MiB chunks to /data/local/tmp, toybox `dd` (no `conv=`,
  it rejects them) at `seek=`, verify with `head -c N | sha256sum`. `adb exec-in` + Magisk `su` passes no stdin.
- **Slot switching:** libavb AvbABData at misc+2048 (magic `\0AB0`, slots {priority, tries, successful},
  big-endian CRC32 of the first 28 bytes). LK `set_active` will not revive a slot marked unbootable.
- **vbmeta:** LK rejects slot B and resets it to unbootable unless vbmeta has rollback index 1, flags 0 and
  descriptors for oem_bootloader/oem/factory (taken from stock vbmeta_b). Unlocked LK allows the test key.
- **Recovery is unreachable:** LK always passes skip_initramfs; `adb reboot recovery` and a BCB
  `boot-recovery` both boot normal Lineage. Wipe /data via fstab `formattable` + zeroed first 4 KiB of
  userdata (fs_mgr `partition_wiped()` needs the whole first 4 KiB zero, from an unmounted state).
- **Binder:** kernel has no CONFIG_ANDROID_BINDER_IPC_32BIT, so `TARGET_USES_64_BIT_BINDER := true`.
- **Display was fine:** the "frozen LENOVO logo" was /oem/media/bootanimation.zip (preferred over
  Lineage's), with the backlight left at 1/255 by LK. init now hides /oem/media and sets brightness 128.
- **adb:** default.prop's ro.adb.secure=1 wins; the host key is baked in as /adb_keys (adb_keys, untracked).
  adb root needs `setprop persist.sys.root_access 3` (lost when /data is wiped).
- Lineage marks slot B successful early (update_verifier at late-fs), so failed boots don't fall back.
