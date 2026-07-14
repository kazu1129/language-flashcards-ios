#!/bin/sh

set -eu

# Keep Xcode Cloud builds well above the latest uploaded 1.0 build (16).
build_number_offset=1000
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

project_file="$repository_path/LanguageFlashcards.xcodeproj/project.pbxproj"
if [ ! -f "$project_file" ]; then
    echo "error: Xcode project file not found: $project_file" >&2
    exit 1
fi

setting_count=$(/usr/bin/grep -Ec '^[[:space:]]*CURRENT_PROJECT_VERSION = [^;]+;' "$project_file" || true)
if [ "$setting_count" -eq 0 ]; then
    echo "error: No CURRENT_PROJECT_VERSION settings found in $project_file." >&2
    exit 1
fi

echo "Setting CURRENT_PROJECT_VERSION to $next_build_number in $setting_count build configurations (offset $build_number_offset + CI build $ci_build_number)."
/usr/bin/sed -i '' -E "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $next_build_number;/g" "$project_file"

updated_count=$(/usr/bin/grep -Ec "^[[:space:]]*CURRENT_PROJECT_VERSION = $next_build_number;" "$project_file" || true)
if [ "$updated_count" -ne "$setting_count" ]; then
    echo "error: Updated $updated_count of $setting_count CURRENT_PROJECT_VERSION settings." >&2
    exit 1
fi

echo "Verified CURRENT_PROJECT_VERSION=$next_build_number in all $updated_count build configurations."
