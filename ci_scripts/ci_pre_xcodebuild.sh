#!/bin/sh

set -eu

# Keep Xcode Cloud builds above the build numbers already uploaded to App Store Connect.
build_number_offset=100
ci_build_number="${CI_BUILD_NUMBER:-}"

case "$ci_build_number" in
    ''|*[!0-9]*)
        echo "error: CI_BUILD_NUMBER must be a non-negative integer." >&2
        exit 1
        ;;
esac

repository_path="${CI_PRIMARY_REPOSITORY_PATH:-}"
if [ -z "$repository_path" ]; then
    echo "error: CI_PRIMARY_REPOSITORY_PATH is not set." >&2
    exit 1
fi

next_build_number=$((build_number_offset + ci_build_number))

cd "$repository_path"
echo "Setting CFBundleVersion to $next_build_number (offset $build_number_offset + CI build $ci_build_number)."
xcrun agvtool new-version -all "$next_build_number"
