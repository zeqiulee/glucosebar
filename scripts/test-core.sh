#!/bin/bash
set -euo pipefail
task_project_dir="$(cd "$(dirname "$0")/.." && pwd)"
task_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/glucosebar-tests.XXXXXX")"
trap 'rm -rf "$task_test_dir"' EXIT
swiftc -swift-version 6 -enable-testing -parse-as-library -emit-library -emit-module -module-name GlucoseCore \
    "$task_project_dir/Sources/GlucoseCore/GlucoseReading.swift" \
    "$task_project_dir/Sources/GlucoseCore/SisensingParser.swift" \
    "$task_project_dir/Sources/GlucoseCore/GlucoseRangeSummary.swift" \
    "$task_project_dir/Sources/GlucoseCore/GlucoseCache.swift" \
    -emit-module-path "$task_test_dir/GlucoseCore.swiftmodule" -o "$task_test_dir/libGlucoseCore.dylib"
swiftc -swift-version 6 -D GLUCOSE_CORE_STANDALONE_TESTS -parse-as-library \
    -I "$task_test_dir" -L "$task_test_dir" -lGlucoseCore -Xlinker -rpath -Xlinker "$task_test_dir" \
    "$task_project_dir/Tests/GlucoseCoreTests/SisensingParserTests.swift" \
    "$task_project_dir/Tests/GlucoseCoreTests/GlucoseRangeSummaryTests.swift" \
    "$task_project_dir/Tests/GlucoseCoreTests/GlucoseCacheTests.swift" \
    "$task_project_dir/Tests/GlucoseCoreTests/StandaloneTestSupport.swift" \
    -o "$task_test_dir/core-tests"
"$task_test_dir/core-tests"
