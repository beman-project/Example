#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Post-generation formatting for copier-generated projects.
#
# Applies the same formatters the generated project's pre-commit config
# enforces (gersemi for CMake, clang-format for C/C++), so a freshly
# generated project is lint-clean on its very first `pre-commit run` and
# its first CI pre-commit check. This matters because gersemi/clang-format
# wrapping decisions depend on the resolved project name length, so the
# static template cannot be pre-formatted for every possible name.
#
# Invoked by copier as a task with CWD set to the generated project root.
# Best-effort: if the formatter tooling is unavailable it warns and exits 0
# rather than aborting project generation.

set -uo pipefail

# Keep these in sync with template/.pre-commit-config.yaml.jinja.
GERSEMI_VERSION="0.27.6"
CLANG_FORMAT_VERSION="22.1.5"

# Directories excluded from formatting (mirrors the pre-commit `exclude`).
prune=(-path ./infra -o -path ./port -o -path ./.git -o -path ./build)

if ! command -v uvx >/dev/null 2>&1; then
    echo "warning: 'uvx' not found; skipping post-generation formatting." >&2
    echo "         Run 'pre-commit run --all-files' after generation to format." >&2
    exit 0
fi

# --- CMake: gersemi ---
mapfile -d '' cmake_files < <(
    find . \( "${prune[@]}" \) -prune -o \
        \( -name CMakeLists.txt -o -name '*.cmake' \) -type f -print0
)
if ((${#cmake_files[@]})); then
    echo "Formatting ${#cmake_files[@]} CMake file(s) with gersemi ${GERSEMI_VERSION}..."
    uvx "gersemi==${GERSEMI_VERSION}" --in-place "${cmake_files[@]}" \
        || echo "warning: gersemi formatting failed; continuing." >&2
fi

# --- C/C++: clang-format ---
mapfile -d '' cpp_files < <(
    find . \( "${prune[@]}" \) -prune -o \
        \( -name '*.cpp' -o -name '*.hpp' -o -name '*.cppm' \
           -o -name '*.cc' -o -name '*.cxx' -o -name '*.h' \
           -o -name '*.hh' -o -name '*.ixx' \) -type f -print0
)
if ((${#cpp_files[@]})); then
    echo "Formatting ${#cpp_files[@]} C/C++ file(s) with clang-format ${CLANG_FORMAT_VERSION}..."
    uvx --from "clang-format==${CLANG_FORMAT_VERSION}" clang-format -i "${cpp_files[@]}" \
        || echo "warning: clang-format formatting failed; continuing." >&2
fi
