#!/bin/bash
set -euo pipefail
task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_output="${1:-$task_project_dir/docs/images}"
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/glucosebar-previews.XXXXXX")"
trap 'rm -rf "$task_tmp"' EXIT
mkdir -p "$task_output"
swiftc -swift-version 6 -parse-as-library -emit-library -emit-module -module-name GlucoseCore \
    "$task_project_dir/Sources/GlucoseCore/GlucoseReading.swift" \
    "$task_project_dir/Sources/GlucoseCore/GlucoseRangeSummary.swift" \
    -emit-module-path "$task_tmp/GlucoseCore.swiftmodule" -o "$task_tmp/libGlucoseCore.dylib"
swiftc -swift-version 6 -parse-as-library -I "$task_tmp" -L "$task_tmp" -lGlucoseCore \
    -Xlinker -rpath -Xlinker "$task_tmp" \
    "$task_project_dir/Sources/GlucoseBar/GlucosePalette.swift" \
    "$task_project_dir/Sources/GlucoseBar/GlucoseTrace.swift" \
    "$task_project_dir/Sources/GlucoseBar/GlucoseChart.swift" \
    "$task_project_dir/Sources/GlucoseBar/GlucoseChartSelection.swift" \
    "$task_project_dir/Sources/GlucoseBar/GlucoseChartMarker.swift" \
    "$task_project_dir/Sources/GlucoseBar/GlucoseRangeLabel.swift" \
    "$task_project_dir/Sources/GlucoseBar/MenuBarSparkline.swift" \
    "$task_project_dir/Sources/GlucoseBar/MenuBarNumber.swift" \
    "$task_project_dir/scripts/render-previews.swift" -o "$task_tmp/render-previews"
"$task_tmp/render-previews" "$task_output"
