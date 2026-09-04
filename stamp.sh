#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

echo "⚠ Note: stamp.sh is deprecated. You can now generate projects directly using:" >&2
echo "   uvx --from copier copier copy \"git+https://github.com/bemanproject/exemplar.git\" <destination>" >&2
echo "   See the README for the updated workflow." >&2
echo "" >&2

{
    if [[ "$1" == "-h" || "$1" == "--help" ]] ; then
        cat <<-'EOF'
        stamp.sh -- beman exemplar template library creation tool

        This script is intended to be run on a fork of exemplar.

        It sets up Copier, renders the template from a temporary snapshot of
        the current repository, replaces the repository's current contents
        with the stamped result, runs pre-commit, switches to a new branch
        'stamp', and creates a git commit.

        All parameters are passed through to the underlying `copier copy`
        invocation.
EOF
    fi
    set -eu
    if ! type -P python3 >/dev/null ; then
        echo "Couldn't find python3 in PATH" >&2
        exit 1
    fi
    declare repo_dir=$(realpath $(dirname "$BASH_SOURCE"))
    cd "$repo_dir"
    declare copier_venv_path
    copier_venv_path=$(mktemp --directory --dry-run)
    python3 -m venv "$copier_venv_path"
    "$copier_venv_path/bin/python3" -m pip install copier pre-commit >& /dev/null
    declare copier_source_path
    copier_source_path=$(mktemp --directory)
    declare copier_out_path
    copier_out_path=$(mktemp --directory)
    declare template_src_path=https://github.com/bemanproject/exemplar.git
    declare template_commit
    template_commit=$(git rev-parse HEAD)
    rsync -a \
        --exclude .git \
        --exclude build \
        --exclude .venv \
        "$repo_dir/" "$copier_source_path/"
    "$copier_venv_path/bin/copier" copy \
        --trust \
        -d template_src_path="$template_src_path" \
        -d template_commit="$template_commit" \
        "$@" \
        "$copier_source_path" \
        "$copier_out_path" \
        >& /dev/null
    git rm -rf . &>/dev/null
    cp -r "$copier_out_path"/. .
    git add . &>/dev/null
    "$copier_venv_path/bin/pre-commit" run --all-files &>/dev/null || true
    git add . &>/dev/null
    git checkout -b stamp
    git commit -q -m "Stamp out exemplar template"
    echo "Successfully stamped out exemplar template to the new branch 'stamp'."
    echo "Try 'git push origin stamp' to push the branch upstream,"
    echo "then create a pull request."
    rm -r "$copier_venv_path" "$copier_source_path" "$copier_out_path"
}; exit
