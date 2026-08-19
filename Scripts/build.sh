#!/bin/bash
set -e

echo "=== [FakeLag] Bắt đầu quá trình biên dịch ứng dụng TrollStore ==="

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
CC=$(xcrun --sdk iphoneos --find clang)
ARCH="arm64"
MIN_IOS_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
OUTPUT_DIR="$ROOT_DIR/output"
PAYLOAD_DIR="$BUILD_DIR/Payload"
APP_DIR="$PAYLOAD_DIR/FakeLag.app"
PLUGINS_DIR="$APP_DIR/PlugIns"
TUNNEL_DIR="$PLUGINS_DIR/FakeLagTunnel.appex"

rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$APP_DIR" "$TUNNEL_DIR" "$OUTPUT_DIR"

CFLAGS="-arch $ARCH -isysroot $SDK_PATH -miphoneos-version-min=$MIN_IOS_VERSION -O3 -fobjc-arc -fmodules -Wno-deprecated-declarations -Wno-unused-variable"
FRAMEWORKS="-framework UIKit -framework Foundation -framework CoreGraphics -framework NetworkExtension -framework QuartzCore -framework AudioToolbox -framework AVFoundation"

echo "1. Biên dịch FakeLagTunnel (Network Extension)..."
$CC $CFLAGS $FRAMEWORKS \
    -e _NSExtensionMain \
    -I"$ROOT_DIR/FakeLagTunnel" \
    "$ROOT_DIR/FakeLagTunnel/PacketTunnelProvider.m" \
    -o "$TUNNEL_DIR/FakeLagTunnel"

cp "$ROOT_DIR/FakeLagTunnel/Info.plist" "$TUNNEL_DIR/Info.plist"

echo "2. Biên dịch FakeLagHUD (Overlay Process)..."
$CC $CFLAGS $FRAMEWORKS \
    "$ROOT_DIR/FakeLagHUD/main.m" \
    "$ROOT_DIR/FakeLagHUD/HUDAppDelegate.m" \
    "$ROOT_DIR/FakeLagHUD/HUDWindow.m" \
    "$ROOT_DIR/FakeLagHUD/HUDViewController.m" \
    "$ROOT_DIR/FakeLag/Managers/RemoteLinkManager.m" \
    "$ROOT_DIR/FakeLag/Managers/VPNManager.m" \
    "$ROOT_DIR/FakeLag/Managers/PacketEngine.m" \
    -I"$ROOT_DIR/FakeLagHUD" \
    -I"$ROOT_DIR/FakeLag/Managers" \
    -o "$APP_DIR/FakeLagHUD"

echo "3. Biên dịch FakeLag (Main Application)..."
$CC $CFLAGS $FRAMEWORKS \
    "$ROOT_DIR/FakeLag/main.m" \
    "$ROOT_DIR/FakeLag/AppDelegate.m" \
    "$ROOT_DIR/FakeLag/SceneDelegate.m" \
    "$ROOT_DIR/FakeLag/Controllers/MainViewController.m" \
    "$ROOT_DIR/FakeLag/Controllers/SettingsViewController.m" \
    "$ROOT_DIR/FakeLag/Managers/RemoteLinkManager.m" \
    "$ROOT_DIR/FakeLag/Managers/HUDLauncher.m" \
    "$ROOT_DIR/FakeLag/Managers/VPNManager.m" \
    "$ROOT_DIR/FakeLag/Managers/PacketEngine.m" \
    "$ROOT_DIR/FakeLagHUD/HUDWindow.m" \
    "$ROOT_DIR/FakeLagHUD/HUDViewController.m" \
    -I"$ROOT_DIR/FakeLag" \
    -I"$ROOT_DIR/FakeLag/Controllers" \
    -I"$ROOT_DIR/FakeLag/Managers" \
    -I"$ROOT_DIR/FakeLagHUD" \
    -o "$APP_DIR/FakeLag"

cp "$ROOT_DIR/FakeLag/Info.plist" "$APP_DIR/Info.plist"

# Gán quyền thực thi cho các file nhị phân
chmod 755 "$APP_DIR/FakeLag"
chmod 755 "$APP_DIR/FakeLagHUD"
chmod 755 "$TUNNEL_DIR/FakeLagTunnel"

echo "4. Ký mã nguồn với đặc quyền TrollStore (ldid)..."
if command -v ldid >/dev/null 2>&1; then
    echo "-> Đang ký FakeLagTunnel với FakeLagTunnel.entitlements"
    ldid -S"$ROOT_DIR/Entitlements/FakeLagTunnel.entitlements" "$TUNNEL_DIR/FakeLagTunnel" || true
    
    echo "-> Đang ký FakeLagHUD với FakeLagHUD.entitlements"
    ldid -S"$ROOT_DIR/Entitlements/FakeLagHUD.entitlements" "$APP_DIR/FakeLagHUD" || true
    
    echo "-> Đang ký FakeLag với FakeLag.entitlements"
    ldid -S"$ROOT_DIR/Entitlements/FakeLag.entitlements" "$APP_DIR/FakeLag" || true
else
    echo "Cảnh báo: Chưa cài đặt ldid, bỏ qua bước ký cục bộ."
fi

echo "5. Đóng gói FakeLag.tipa và FakeLag.ipa..."
cd "$BUILD_DIR"
zip -r9 "$OUTPUT_DIR/FakeLag.tipa" Payload
cp "$OUTPUT_DIR/FakeLag.tipa" "$OUTPUT_DIR/FakeLag.ipa"

echo "=== [FakeLag] Hoàn tất! File đã tạo tại: ==="
echo " -> $OUTPUT_DIR/FakeLag.tipa"
echo " -> $OUTPUT_DIR/FakeLag.ipa"
