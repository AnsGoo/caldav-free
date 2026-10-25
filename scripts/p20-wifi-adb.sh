#!/usr/bin/env bash
# Enable ADB over Wi-Fi for a Huawei P20 (Android 9/10, no `adb pair`).
#
# The P20 predates Android 11 wireless debugging, so the USB cable must be
# connected once to switch adbd into TCP mode:
#
#   1. Settings -> About phone -> tap Build number 7x
#   2. Developer options -> USB debugging ON
#      (Huawei: also "Allow ADB debugging in charge only mode" ON)
#   3. Plug in USB, unlock the phone, accept the RSA fingerprint
#   4. Run this script
#
# Usage:
#   scripts/p20-wifi-adb.sh
#   ADB_PORT=5556 scripts/p20-wifi-adb.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${ADB_PORT:-5555}"
ADB="${ADB:-}"
if [ -z "$ADB" ]; then
  if command -v adb >/dev/null 2>&1; then
    ADB="$(command -v adb)"
  elif [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
    ADB="$ANDROID_HOME/platform-tools/adb"
  elif [ -x "$HOME/development/android-sdk/platform-tools/adb" ]; then
    ADB="$HOME/development/android-sdk/platform-tools/adb"
  else
    echo "adb not found; set ADB=/path/to/adb or ANDROID_HOME" >&2
    exit 1
  fi
fi

echo "==> adb devices"
"$ADB" devices -l

# Prefer a USB device over the emulator / existing TCP devices.
USB_SERIAL="$("$ADB" devices | awk 'NR>1 && $2=="device" && $1 !~ /:/ && $1 !~ /^emulator-/ {print $1; exit}')"
if [ -z "$USB_SERIAL" ]; then
  cat >&2 <<'MSG'
No USB-connected device found.

On the Huawei P20:
  1. Enable Developer options (tap Build number 7 times).
  2. Enable USB debugging and "Allow ADB debugging in charge only mode".
  3. Connect the USB cable, unlock the phone, accept the RSA prompt.

Then rerun this script. The P20 has no Android 11 `adb pair` flow, so this
first USB step is required.
MSG
  exit 1
fi
echo "==> USB device: $USB_SERIAL"

PHONE_IP="$("$ADB" -s "$USB_SERIAL" shell 'ip -f inet addr show wlan0 2>/dev/null' 2>/dev/null \
  | awk '/inet /{print $2}' | cut -d/ -f1 | head -1 | tr -d '\r')"
if [ -z "$PHONE_IP" ]; then
  PHONE_IP="$("$ADB" -s "$USB_SERIAL" shell getprop dhcp.wlan0.ipaddress 2>/dev/null | tr -d '\r')"
fi
if [ -z "$PHONE_IP" ]; then
  echo "Could not read the phone's Wi-Fi IP. Connect the phone to the same Wi-Fi, then rerun." >&2
  exit 1
fi
echo "==> phone Wi-Fi IP: $PHONE_IP"

echo "==> switching adbd to TCP port $PORT"
"$ADB" -s "$USB_SERIAL" tcpip "$PORT"
sleep 2

echo "==> adb connect $PHONE_IP:$PORT"
"$ADB" connect "$PHONE_IP:$PORT"

echo "==> devices"
"$ADB" devices -l

MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [ -z "$MAC_IP" ]; then
  MAC_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

cat <<EOF

Wi-Fi ADB is ready. You can unplug USB now.

Install/run:
  $ADB -s $PHONE_IP:$PORT install -r "$ROOT/mobile/build/app/outputs/flutter-apk/app-debug.apk"
  cd "$ROOT/mobile" && flutter devices
  cd "$ROOT/mobile" && flutter run -d $PHONE_IP:$PORT

Backend:
  The phone cannot use 10.0.2.2 (that is emulator-only).
  Start the Go server bound to all interfaces:
    go run ./cmd/caldav-free -data /tmp/caldav-phone-data -addr :5232
  In the app use: http://${MAC_IP:-<mac-wifi-ip>}:5232

Troubleshooting:
  - Both devices must be on the same Wi-Fi and the network must allow client
    isolation (guest Wi-Fi usually does not).
  - If "adb devices" shows "unauthorized": unlock the phone and accept the RSA
    prompt; otherwise revoke USB debugging authorizations and reconnect USB.
  - If the install is blocked: enable "Install via USB" / disable
    "Monitor ADB installation" in Developer options.
  - TCP adbd resets on reboot; run this script again with USB.
  - Disable Wi-Fi ADB: adb disconnect $PHONE_IP:$PORT (or adb usb with USB attached).
EOF
