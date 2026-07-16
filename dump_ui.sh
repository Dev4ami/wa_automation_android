#!/usr/bin/env bash
# Dump UI hierarchy dari device ke file lokal.
# Pakai: bash dump_ui.sh <nama> [serial]
#   <nama>   -> hasil: dump_<nama>.xml di folder ini
#   [serial] -> opsional, kalau banyak device (lihat: adb devices)
#
# Path device di-hardcode /sdcard/dump.xml; MSYS_NO_PATHCONV cegah Git Bash
# ngubah /sdcard jadi path Windows.
name="${1:-dump}"
serial="$2"
sel=""
[ -n "$serial" ] && sel="-s $serial"

MSYS_NO_PATHCONV=1 adb $sel shell uiautomator dump /sdcard/dump.xml >/dev/null || { echo "DUMP GAGAL"; exit 1; }
MSYS_NO_PATHCONV=1 adb $sel pull /sdcard/dump.xml "D:/shell/wa_automation_android/dump_${name}.xml" && echo "OK -> dump_${name}.xml"
