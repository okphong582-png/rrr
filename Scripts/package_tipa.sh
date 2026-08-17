#!/bin/bash
set -e

APP_PATH="$1"
OUTPUT_TIPA="$2"

if [ -z "$APP_PATH" ]; then
    echo "Sử dụng: ./package_tipa.sh <PathToApp.app> [Output.tipa]"
    exit 1
fi

if [ -z "$OUTPUT_TIPA" ]; then
    OUTPUT_TIPA="FakeLag.tipa"
fi

TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/Payload"
cp -R "$APP_PATH" "$TEMP_DIR/Payload/"

cd "$TEMP_DIR"
zip -r9 "$OUTPUT_TIPA" Payload
mv "$OUTPUT_TIPA" "$(pwd)/$OUTPUT_TIPA"
rm -rf "$TEMP_DIR"

echo "Đã tạo thành công: $OUTPUT_TIPA"
