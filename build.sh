#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
OUTPUT_DIR="${SCRIPT_DIR}/dist"
APP_NAME="桌面倒计时.app"
APP_DIR="${OUTPUT_DIR}/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BUILD_DIR="${SCRIPT_DIR}/.build"
COMPATIBLE_CLT_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ -n "${DESKTOP_COUNTDOWN_SDK:-}" ]]; then
    SDK_PATH="${DESKTOP_COUNTDOWN_SDK}"
elif [[ -d "${COMPATIBLE_CLT_SDK}" ]]; then
    SDK_PATH="${COMPATIBLE_CLT_SDK}"
else
    SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
fi
HOST_ARCHITECTURE="$(uname -m)"
MODULE_CACHE="${BUILD_DIR}/ModuleCache"

mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}" "${MODULE_CACHE}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

ICON_GENERATOR="${BUILD_DIR}/IconGenerator"
ICNS_PACKER="${BUILD_DIR}/ICNSPack"
ICON_BASE="${BUILD_DIR}/AppIcon-1024.png"
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"

SDKROOT="${SDK_PATH}" xcrun swiftc \
    -swift-version 5 \
    -O \
    -sdk "${SDK_PATH}" \
    -target "${HOST_ARCHITECTURE}-apple-macosx13.0" \
    -module-cache-path "${MODULE_CACHE}" \
    -framework AppKit \
    "${SCRIPT_DIR}/Tools/IconGenerator.swift" \
    -o "${ICON_GENERATOR}"

"${ICON_GENERATOR}" "${ICON_BASE}"

SDKROOT="${SDK_PATH}" xcrun swiftc \
    -swift-version 5 \
    -O \
    -sdk "${SDK_PATH}" \
    -target "${HOST_ARCHITECTURE}-apple-macosx13.0" \
    -module-cache-path "${MODULE_CACHE}" \
    "${SCRIPT_DIR}/Tools/ICNSPack.swift" \
    -o "${ICNS_PACKER}"

rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"
for spec in \
    "16 icon_16x16.png" \
    "32 icon_16x16@2x.png" \
    "32 icon_32x32.png" \
    "64 icon_32x32@2x.png" \
    "128 icon_128x128.png" \
    "256 icon_128x128@2x.png" \
    "256 icon_256x256.png" \
    "512 icon_256x256@2x.png" \
    "512 icon_512x512.png" \
    "1024 icon_512x512@2x.png"; do
    size="${spec%% *}"
    name="${spec#* }"
    sips -z "${size}" "${size}" "${ICON_BASE}" --out "${ICONSET_DIR}/${name}" >/dev/null
done
"${ICNS_PACKER}" "${ICONSET_DIR}" "${RESOURCES_DIR}/AppIcon.icns"

ARM_BINARY="${BUILD_DIR}/DesktopCountdown-arm64"
INTEL_BINARY="${BUILD_DIR}/DesktopCountdown-x86_64"

for architecture in arm64 x86_64; do
    if [[ "${architecture}" == "arm64" ]]; then
        architecture_binary="${ARM_BINARY}"
    else
        architecture_binary="${INTEL_BINARY}"
    fi

    SDKROOT="${SDK_PATH}" xcrun swiftc \
        -swift-version 5 \
        -O \
        -sdk "${SDK_PATH}" \
        -target "${architecture}-apple-macosx13.0" \
        -module-cache-path "${MODULE_CACHE}" \
        -framework AppKit \
        -framework CoreGraphics \
        -framework ImageIO \
        "${SCRIPT_DIR}/Sources/DesktopCountdown/Dashboard.swift" \
        "${SCRIPT_DIR}/Sources/DesktopCountdown/main.swift" \
        -o "${architecture_binary}"
done

lipo -create "${ARM_BINARY}" "${INTEL_BINARY}" -output "${MACOS_DIR}/DesktopCountdown"

cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${SCRIPT_DIR}/README.md" "${OUTPUT_DIR}/桌面倒计时-使用说明.md"
chmod +x "${MACOS_DIR}/DesktopCountdown"

codesign --force --deep --sign - "${APP_DIR}" >/dev/null
touch "${APP_DIR}"

ZIP_PATH="${OUTPUT_DIR}/桌面倒计时-macOS.zip"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "Built: ${APP_DIR}"
echo "Archive: ${ZIP_PATH}"
