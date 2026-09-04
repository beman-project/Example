#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
set -euo pipefail
CMAKE_COMMAND="${CMAKE_COMMAND:-cmake}"
CTEST_COMMAND="${CTEST_COMMAND:-ctest}"


script_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
repo_root=$(realpath "$script_dir/..")

PRESET=${1:-gcc-release}

test_project_variant() {
    local variant_name="$1"
    local unit_test_library="$2"
    local use_modules="$3"
    local cmakelists_args=""

    if [[ "$use_modules" == "true" ]]; then
        cmakelists_args="-DBEMAN_TEST_PROJECT_USE_MODULES=ON"
    fi

    echo "=========================================================="
    echo "Testing variant: $variant_name"
    echo "Unit test: $unit_test_library, Modules: $use_modules, Preset: $PRESET"
    echo "=========================================================="

    local work_dir
    work_dir=$(mktemp -d)
    echo "Generating standard project in $work_dir..."

    # Use `--vcs-ref HEAD` in CI environment so we test the most recent commit
    # but use local tree if uncommitted for fast iteration locally. Use dirty copier behavior locally.
    uvx --from copier copier copy \
        --trust \
        --defaults \
        --vcs-ref=HEAD \
        -d project_name=test_project \
        -d generating_exemplar=false \
        -d unit_test_library="$unit_test_library" \
        "$repo_root" \
        "$work_dir"

    echo "Building standard project variant $variant_name..."
    pushd "$work_dir" > /dev/null
    "$CMAKE_COMMAND" --preset "$PRESET" -B build $cmakelists_args || {
        echo -e "\n\n*** configure failed: $variant_name ***"
        echo "*** Sometimes local CMake modules require a newer compiler than the host default."
        # If failure is just a module C++ scan lack of support, we could suppress, but let's hard fail.
        popd > /dev/null && rm -rf "$work_dir"
        exit 1
    }
    "$CMAKE_COMMAND" --build build
    "$CTEST_COMMAND" --test-dir build --output-on-failure

    # Cleanup this variant's dir
    popd > /dev/null && rm -rf "$work_dir"
    echo "✔ Success for variant: $variant_name"
}

# 1. GTest + No Modules
test_project_variant "gtest-no-modules" "gtest" "false"

# 2. Catch2 + No Modules
test_project_variant "catch2-no-modules" "catch2" "false"

# 3. GTest + Modules
# This is the variant that gives copier-cmake-matrix its purpose: it is the only
# one that consumes infra/cmake/enable-experimental-import-std.cmake, whose
# CMAKE_EXPERIMENTAL_CXX_IMPORT_STD value changes from CMake release to release.
# Run it only in CI, where the container guarantees a compiler new enough for
# `import std`, and only for CMake 3.31 and later: 3.30 cannot discover `import
# std` support for GCC at all ("Toolchain does not support discovering `import
# std` support"), regardless of the UUID.
cmake_version=$("$CMAKE_COMMAND" --version | head -n 1 | awk '{print $3}')
if [[ "${GITHUB_ACTIONS:-false}" == "true" ]] &&
    [[ "$(printf '%s\n%s\n' 3.31 "$cmake_version" | sort -V | head -n 1)" == "3.31" ]]; then
    test_project_variant "gtest-modules" "gtest" "true"
else
    echo "Skipping modules variant (CMake $cmake_version, GITHUB_ACTIONS=${GITHUB_ACTIONS:-false})"
fi

echo "=========================================================="
echo "✔ All variants successfully generated, built, and tested! "
echo "=========================================================="
