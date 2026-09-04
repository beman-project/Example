#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
set -euo pipefail

script_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

PRESET=${1:-gcc-release}
CMAKE_VERSION=${2:-latest}

if [[ "$CMAKE_VERSION" == "latest" || -z "$CMAKE_VERSION" ]]; then
    export CMAKE_COMMAND="cmake"
    export CTEST_COMMAND="ctest"
    echo "Running with default host CMake"
else
    echo "Provisioning standard environment for CMake $CMAKE_VERSION"
    venv_dir=$(mktemp -d)
    uv venv "$venv_dir" > /dev/null
    uv pip install "cmake==${CMAKE_VERSION}" --python "$venv_dir" > /dev/null
    export CMAKE_COMMAND="$venv_dir/bin/cmake"
    export CTEST_COMMAND="$venv_dir/bin/ctest"

    echo "Using CMake: $("$CMAKE_COMMAND" --version | head -n 1)"

    cleanup() {
        rm -rf "$venv_dir"
    }
    trap cleanup EXIT
fi

"$script_dir/test_standard_project.sh" "$PRESET"
