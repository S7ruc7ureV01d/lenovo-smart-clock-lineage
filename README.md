# LineageOS 16.0 for the Lenovo Smart Clock (CD-24501F)

Bring-up of LineageOS 16.0 (Android 9) on the Lenovo Smart Clock (MT8167S,
1 GB RAM, stock Android Things 8.1). Status and every finding so far are in
[FINDINGS.md](FINDINGS.md).

## Layout

- `android/device/lenovo/cd24501f/`: device tree (goes to
  `device/lenovo/cd24501f` in the LineageOS tree)
- `kernel/cd24501f_defconfig`: kernel config; copy to
  `arch/arm64/configs/` of
  [deadman96385/android_kernel_lenovo_mt8167s](https://github.com/deadman96385/android_kernel_lenovo_mt8167s)
  (`kernel/lenovo/mt8167s`, see `lineage.dependencies`)
- `tools/`: flashing helpers. LK's fastboot hangs with the stock client, so
  `fbmulti.py` (pyusb) flashes in one USB session; `sparsesplit.py` splits
  `system.img` under LK's 96 MiB max-download-size.

## Build

1. `repo init -u https://github.com/LineageOS/android.git -b lineage-16.0`,
   `repo sync`, then put the device tree and kernel in place.
2. Create `BoardConfigPartitions.mk` from the `.example`.
3. Extract blobs with `extract-files.sh` (not included here).
4. Optional: copy `~/.android/adbkey.pub` to the device tree as `adb_keys`.
5. `. build/envsetup.sh && lunch lineage_cd24501f-userdebug && mka`

## Flash (slot B, keep stock on slot A)

```
simg2img vendor.img vendor.raw
python3 tools/sparsesplit.py system.img system_chunk 94371840
python3 tools/fbmulti.py boot.img=boot_b vendor.raw=vendor_b \
    system_chunk.0=system_b ... system_chunk.5=system_b \
    vbmeta.img=vbmeta_b cmd:set_active:b
```

Never flash `oem_*`, `oem_bootloader_*`, `lk`, `tee` or the preloader.
