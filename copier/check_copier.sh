#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

set -euo pipefail

script_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
repo_root=$(realpath "$script_dir/..")

cleanup() {
    if [[ -n "${work_dir:-}" && -d "$work_dir" ]]; then
        rm -rf "$work_dir"
    fi
    if [[ -n "${copier_venv_path:-}" && -d "$copier_venv_path" ]]; then
        rm -rf "$copier_venv_path"
    fi
}

setup_venv() {
    local path="$1" ; shift
    python3 -m venv "$path"
    "$path/bin/python3" -m pip install copier >& /dev/null
    COPIER_BIN="$path/bin/copier"
}

template_commit() {
    git -C "$repo_root" rev-parse HEAD
}

prepare_template_source() {
    local source_dir="$1" ; shift
    local prepared_source
    prepared_source=$(mktemp -d)
    rsync -a \
        --exclude .git \
        --exclude build \
        --exclude .venv \
        "$source_dir/" "$prepared_source/"
    printf '%s\n' "$prepared_source"
}

stamp() {
    local template_source="$1" ; shift
    local output_dir="$1" ; shift
    local unit_test_library="$1" ; shift
    local generating_exemplar="$1" ; shift
    local prepared_source
    prepared_source=$(prepare_template_source "$template_source")
    "$COPIER_BIN" copy \
        --trust \
        --defaults \
        -d template_src_path=https://github.com/bemanproject/exemplar.git \
        -d template_commit="$(template_commit)" \
        -d project_name=exemplar \
        -d maintainer=steve-downey \
        -d minimum_cpp_build_version=17 \
        -d paper=P0898R3 \
        -d description="A Beman Library Exemplar" \
        -d unit_test_library="$unit_test_library" \
        -d generating_exemplar="$generating_exemplar" \
        -d owner=bemanproject \
        -d ci_tests_cron="30 15 * * 6" \
        -d pre_commit_update_cron="0 16 * * 0" \
        "$prepared_source" \
        "$output_dir" \
        >& /dev/null
    rm -rf "$prepared_source"
}

check_consistency() {
    local output_dir="$work_dir/default"
    mkdir -p "$output_dir"
    stamp "$repo_root" "$output_dir" "gtest" "true"

    local diff_path="$work_dir/default.diff"
    diff -u -r \
        --exclude .git \
        --exclude .claude \
        --exclude build \
        --exclude .venv \
        --exclude template \
        --exclude copier \
        --exclude copier.yml \
        --exclude stamp.sh \
        --exclude images \
        --exclude .copier-answers.yml \
        --exclude copier_test.yml \
        --exclude catch2_exemplar_test.yml \
        --exclude todo_exemplar_test.yml \
        "$repo_root" "$output_dir" > "$diff_path" || true

    if [[ -s "$diff_path" ]] ; then
        echo "Discrepancy between exemplar and copier output:" >&2
        cat "$diff_path" >&2
        exit 1
    fi
}

check_templating() {
    local output_dir="$work_dir/randomized"
    local prepared_source
    mkdir -p "$output_dir"
    prepared_source=$(prepare_template_source "$repo_root")
    "$COPIER_BIN" copy \
        --trust \
        --defaults \
        -d template_src_path=https://github.com/bemanproject/exemplar.git \
        -d template_commit="$(template_commit)" \
        -d project_name=rlzrmx9nfs \
        -d maintainer=octocat \
        -d minimum_cpp_build_version=17 \
        -d paper=P0898R3 \
        -d description="A Beman Library rlzrmx9nfs" \
        -d unit_test_library=gtest \
        -d generating_exemplar=false \
        -d owner=bemanproject \
        -d ci_tests_cron="30 15 * * 6" \
        -d pre_commit_update_cron="0 16 * * 0" \
        "$prepared_source" \
        "$output_dir" \
        >& /dev/null
    rm -rf "$prepared_source"

    rm -rf "$output_dir/infra"

    local grep_path="$work_dir/randomized.grep"
    grep \
        --dereference-recursive --context=5 --color=always \
        --exclude .copier-answers.yml \
        -e "exemplar" -e "identity" "$output_dir" > "$grep_path" || true

    if [[ -s "$grep_path" ]] ; then
        echo 'Untemplated "exemplar" or "identity" in copier output:' >&2
        cat "$grep_path" >&2
        exit 1
    fi
}

main() {
    work_dir=$(mktemp -d)
    copier_venv_path=$(mktemp -d)
    trap cleanup EXIT
    setup_venv "$copier_venv_path"
    check_consistency
    check_templating
    echo "Success: Template matches project exactly."
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main "$@"
