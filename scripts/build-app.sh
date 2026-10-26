#!/bin/bash
set -euo pipefail

task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_destination="${1:-$task_project_dir/dist}"
task_scratch_dir="${GLUCOSEBAR_BUILD_DIR:-$task_project_dir/.build}"
task_arch="${GLUCOSEBAR_ARCH:-$(uname -m)}"
task_identity="${GLUCOSEBAR_SIGN_IDENTITY:--}"
task_bundle_id="${GLUCOSEBAR_BUNDLE_ID:-io.github.zeqiulee.GlucoseBar}"
task_version="$(tr -d '[:space:]' < "$task_project_dir/VERSION")"
task_build_number="$(tr -d '[:space:]' < "$task_project_dir/BUILD_NUMBER")"
[[ "$task_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'VERSION must contain X.Y.Z.\n' >&2; exit 1; }
[[ "$task_build_number" =~ ^[1-9][0-9]*$ ]] || { printf 'BUILD_NUMBER must be a positive integer.\n' >&2; exit 1; }
[[ "$task_bundle_id" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+[A-Za-z0-9]$ ]] || { printf 'Invalid bundle identifier.\n' >&2; exit 1; }
case "$task_arch" in arm64|x86_64|universal) ;; *) printf 'GLUCOSEBAR_ARCH must be arm64, x86_64, or universal.\n' >&2; exit 1 ;; esac

mkdir -p "$task_destination" "$task_scratch_dir"
task_destination="$(cd "$task_destination" && pwd)"
task_scratch_dir="$(cd "$task_scratch_dir" && pwd)"
task_stage="$(mktemp -d "$task_destination/.GlucoseBar-build.XXXXXX")"
trap 'rm -rf "$task_stage"' EXIT
task_app="$task_stage/GlucoseBar.app"
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources"

task_build_arch() {
    local task_target_arch="$1"
    swift build --package-path "$task_project_dir" --scratch-path "$task_scratch_dir" -c release --arch "$task_target_arch"
}
task_binary_path() {
    swift build --package-path "$task_project_dir" --scratch-path "$task_scratch_dir" -c release --arch "$1" --show-bin-path
}
if [[ "$task_arch" == universal ]]; then
    task_build_arch arm64
    task_arm_binary="$(task_binary_path arm64)/GlucoseBar"
    task_build_arch x86_64
    task_intel_binary="$(task_binary_path x86_64)/GlucoseBar"
    lipo -create "$task_arm_binary" "$task_intel_binary" -output "$task_app/Contents/MacOS/GlucoseBar"
    lipo "$task_app/Contents/MacOS/GlucoseBar" -verify_arch arm64 x86_64
else
    task_build_arch "$task_arch"
    cp "$(task_binary_path "$task_arch")/GlucoseBar" "$task_app/Contents/MacOS/GlucoseBar"
    lipo "$task_app/Contents/MacOS/GlucoseBar" -verify_arch "$task_arch"
fi

cat > "$task_app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
<key>CFBundleExecutable</key><string>GlucoseBar</string>
<key>CFBundleIdentifier</key><string>$task_bundle_id</string>
<key>CFBundleName</key><string>GlucoseBar</string>
<key>CFBundleDisplayName</key><string>GlucoseBar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$task_version</string>
<key>CFBundleVersion</key><string>$task_build_number</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
plutil -lint "$task_app/Contents/Info.plist"
task_icon_dir="$task_stage/AppIcon.iconset"
mkdir -p "$task_icon_dir"
swift "$task_project_dir/scripts/make-icon.swift" "$task_stage/app-icon.png"
for task_size in 16 32 128 256 512; do
    sips -z "$task_size" "$task_size" "$task_stage/app-icon.png" --out "$task_icon_dir/icon_${task_size}x${task_size}.png" >/dev/null
    task_double=$((task_size * 2))
    sips -z "$task_double" "$task_double" "$task_stage/app-icon.png" --out "$task_icon_dir/icon_${task_size}x${task_size}@2x.png" >/dev/null
done
iconutil -c icns "$task_icon_dir" -o "$task_app/Contents/Resources/AppIcon.icns"
if [[ "$task_identity" == - ]]; then
    codesign --force --sign - --identifier "$task_bundle_id" "$task_app"
    printf 'Signing: ad hoc; this build is NOT notarized.\n'
else
    codesign --force --options runtime --timestamp --sign "$task_identity" --identifier "$task_bundle_id" "$task_app"
    printf 'Signing: supplied identity with hardened runtime and secure timestamp; notarization is a separate step.\n'
fi
codesign --verify --deep --strict "$task_app"
# Only replace the generated output after the fresh staged bundle has passed verification.
rm -rf "$task_destination/GlucoseBar.app"
mv "$task_app" "$task_destination/GlucoseBar.app"
printf 'Built GlucoseBar %s (%s), %s: %s\n' "$task_version" "$task_build_number" "$task_arch" "$task_destination/GlucoseBar.app"
