#!/bin/bash
set -euo pipefail

task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_destination="${1:-$task_project_dir/dist}"
task_arch="${GLUCOSEBAR_ARCH:-$(uname -m)}"
task_identity="${GLUCOSEBAR_SIGN_IDENTITY:--}"
task_notary_profile="${GLUCOSEBAR_NOTARY_PROFILE:-}"
task_version="$(tr -d '[:space:]' < "$task_project_dir/VERSION")"
task_release_tag="${GLUCOSEBAR_RELEASE_TAG:-v$task_version}"
[[ "$task_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'VERSION must contain X.Y.Z.\n' >&2; exit 1; }
task_version_pattern="${task_version//./\\.}"
[[ "$task_release_tag" =~ ^v${task_version_pattern}(-beta\.[1-9][0-9]*)?$ ]] || { printf 'Release tag must match VERSION, optionally followed by -beta.N.\n' >&2; exit 1; }
case "$task_arch" in arm64|x86_64|universal) ;; *) printf 'GLUCOSEBAR_ARCH must be arm64, x86_64, or universal.\n' >&2; exit 1 ;; esac
if [[ -n "$task_notary_profile" && "$task_identity" == - ]]; then
    printf 'Notarization requires GLUCOSEBAR_SIGN_IDENTITY set to a Developer ID Application identity.\n' >&2
    exit 1
fi

mkdir -p "$task_destination"
task_destination="$(cd "$task_destination" && pwd)"
task_stage="$(mktemp -d "${TMPDIR:-/tmp}/glucosebar-release.XXXXXX")"
trap 'rm -rf "$task_stage"' EXIT
GLUCOSEBAR_ARCH="$task_arch" "$task_project_dir/scripts/build-app.sh" "$task_stage/build"
task_app="$task_stage/build/GlucoseBar.app"
task_status=unnotarized
if [[ -n "$task_notary_profile" ]]; then
    ditto -c -k --norsrc --noextattr --noacl --keepParent "$task_app" "$task_stage/notary-upload.zip"
    xcrun notarytool submit "$task_stage/notary-upload.zip" --keychain-profile "$task_notary_profile" --wait --output-format json > "$task_stage/notary-result.json"
    task_notary_status="$(plutil -extract status raw "$task_stage/notary-result.json")"
    [[ "$task_notary_status" == Accepted ]] || { printf 'Notarization did not return Accepted; no notarized package was created.\n' >&2; exit 1; }
    xcrun stapler staple "$task_app"
    xcrun stapler validate "$task_app"
    codesign --verify --deep --strict "$task_app"
    spctl --assess --type execute "$task_app"
    task_status=notarized
fi

task_asset_name="GlucoseBar-${task_release_tag#v}-macOS-${task_arch}-${task_status}.zip"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$task_app" "$task_stage/$task_asset_name"
unzip -tq "$task_stage/$task_asset_name"
mv "$task_stage/$task_asset_name" "$task_destination/$task_asset_name"
(
    cd "$task_destination"
    shasum -a 256 "$task_asset_name" > "$task_asset_name.sha256"
    shasum -a 256 -c "$task_asset_name.sha256"
)
printf 'Packaged %s\nDistribution status: %s\n' "$task_destination/$task_asset_name" "$task_status"
if [[ "$task_status" == unnotarized ]]; then
    printf 'This package has NOT passed Apple notarization. Do not describe it as notarized.\n'
fi
