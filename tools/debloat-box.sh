#!/usr/bin/env bash
# ==============================================================================
# TV Box Debloater & Malware Cleanup Tool
# Target Hardware: Allwinner H313 / H616 (TX20 Pro, titan-p1, HiBOX1684)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LISTS_DIR="${SCRIPT_DIR}/package-lists"
DISABLED_LIST="${LISTS_DIR}/all-disabled-packages.txt"
LAUNCHER_APK="${SCRIPT_DIR}/tvlauncher.apk"

DEVICE="${1:-}"

if [[ -n "${DEVICE}" ]]; then
    ADB="adb -s ${DEVICE}"
else
    ADB="adb"
fi

echo "=========================================================="
echo " TV Box Debloater & Malware Cleanup Utility"
echo "=========================================================="

# Check ADB connectivity
if ! ${ADB} get-state >/dev/null 2>&1; then
    echo "[!] Error: No ADB device connected or authorized."
    echo "    Make sure USB/Network debugging is ON and accepted."
    exit 1
fi

MODEL=$(${ADB} shell getprop ro.product.model | tr -d '\r')
SOC=$(${ADB} shell getprop ro.board.platform | tr -d '\r')
REAL_SDK=$(${ADB} shell getprop ro.build.version.sdk | tr -d '\r')
BEFORE_COUNT=$(${ADB} shell pm list packages | wc -l)

echo "[+] Connected to: ${MODEL} (SoC: ${SOC}, Android SDK: ${REAL_SDK})"
echo "[+] Starting package count: ${BEFORE_COUNT}"

# 1. Install lightweight TV launcher
if [[ -f "${LAUNCHER_APK}" ]]; then
    echo "[+] Installing TV Launcher (1.1 MB)..."
    ${ADB} install -r "${LAUNCHER_APK}"
    ${ADB} shell "cmd package set-home-activity com.tvlauncher/.MainActivity"
    echo "[+] Set TV Launcher as default home activity."
else
    echo "[!] Warning: ${LAUNCHER_APK} not found. Skipping launcher install."
fi

# 2. Display & performance calibration (fix zoomed-in 720p scaling & disable animation lag)
echo "[+] Setting optimal display density (160 DPI)..."
${ADB} shell "wm density 160"
echo "[+] Optimizing window animations to 0 for instant UI response..."
${ADB} shell "settings put global window_animation_scale 0; settings put global transition_animation_scale 0; settings put global animator_duration_scale 0"
${ADB} shell "settings put global ble_scan_always_enabled 0" 2>/dev/null || true

# 3. Grant install permissions to file manager
echo "[+] Pre-authorizing stock file manager for USB APK installation..."
${ADB} shell "appops set com.softwinner.TvdFileManager REQUEST_INSTALL_PACKAGES allow" 2>/dev/null || true

# 4. Disable malware, bloat, Google suite, and dead weight
echo "[+] Disabling malware and bloatware packages..."
TOTAL_DISABLED=0
while IFS= read -r pkg || [[ -n "${pkg}" ]]; do
    [[ -z "${pkg}" || "${pkg}" =~ ^# ]] && continue
    if ${ADB} shell "pm list packages" | grep -q "^package:${pkg}$"; then
        echo "  [-] Disabling: ${pkg}"
        ${ADB} shell "pm uninstall -k --user 0 ${pkg}" >/dev/null 2>&1 || true
        TOTAL_DISABLED=$((TOTAL_DISABLED + 1))
    fi
done < "${DISABLED_LIST}"

AFTER_COUNT=$(${ADB} shell pm list packages | wc -l)
echo "=========================================================="
echo "[✓] Debloat complete!"
echo "    Packages disabled: ${TOTAL_DISABLED}"
echo "    Initial package count: ${BEFORE_COUNT}"
echo "    Final active package count: ${AFTER_COUNT}"
echo "    Rollback list saved at: ${DISABLED_LIST}"
echo "=========================================================="
