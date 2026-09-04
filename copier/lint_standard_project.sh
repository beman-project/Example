#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Generate a standard (non-exemplar) project from the template and verify it
# is lint-clean on its very first `pre-commit run --all-files`. This exercises
# the post-generation formatting task (copier/format_project.sh) and the
# generated project's own pre-commit config (gersemi, clang-format,
# beman-tidy, ...), catching template changes that would leave a freshly
# generated project failing its own CI lint check.

set -euo pipefail

script_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
repo_root=$(realpath "$script_dir/..")

# beman-tidy derives the expected library/target names from the repository
# directory name, so generate into a directory named after the project.
project_name=${1:-my_project}

work_dir=$(mktemp -d)
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT

out_dir="$work_dir/$project_name"
echo "Generating standard project '$project_name' in $out_dir..."

# Use `--vcs-ref HEAD` so we exercise the most recent commit, matching
# test_standard_project.sh.
uvx --from copier copier copy \
    --trust \
    --defaults \
    --vcs-ref=HEAD \
    -d project_name="$project_name" \
    -d generating_exemplar=false \
    -d unit_test_library=gtest \
    "$repo_root" \
    "$out_dir"

cd "$out_dir"

# pre-commit needs a git repository; beman-tidy expects the default branch to
# be `main`.
git -c init.defaultBranch=main init -q
git config user.email "ci@example.com"
git config user.name "Beman CI"
git add -A
git commit -qm "Generated standard project"

echo "Running pre-commit on the generated project..."
uvx pre-commit run --all-files --show-diff-on-failure

echo "✔ Generated project '$project_name' self-lints cleanly."
