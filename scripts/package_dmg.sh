#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-AutoImeSwitcher}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${ROOT_DIR}/dist/MacOS/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
DMG_TEMP="${DIST_DIR}/${APP_NAME}-temp.dmg"
STAGING_DIR="${DIST_DIR}/${APP_NAME}-dmg"

bash "${ROOT_DIR}/scripts/package_app.sh"
python3 "${ROOT_DIR}/scripts/generate_dmg_background.py"

rm -f "${DMG_PATH}"
rm -f "${DMG_TEMP}"
rm -rf "${STAGING_DIR}"

mkdir -p "${STAGING_DIR}"
cp -R "${APP_DIR}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s "/Applications" "${STAGING_DIR}/Applications"
mkdir -p "${STAGING_DIR}/.background"
cp "${ROOT_DIR}/Resources/dmg-background.png" "${STAGING_DIR}/.background/background.png"

hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDRW "${DMG_TEMP}"
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | awk '/\/Volumes\// {print $3}')

osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 800, 580}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" to {170, 190}
        set position of item "Applications" to {430, 190}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sync
hdiutil detach "${DEVICE}"
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -ov -o "${DMG_PATH}"
rm -f "${DMG_TEMP}"
rm -rf "${STAGING_DIR}"

echo "DMG generated at: ${DMG_PATH}"
