#!/bin/bash
# Prove that two isolated proof exports have identical bytes and leave the checkout untouched.
set -eu

usage() {
    echo "usage: core-box-repro-check.sh --checked-out-assets ABSOLUTE_DIRECTORY --profile pipeline-spike-v1|production-v1" >&2
    exit 64
}

CHECKED_OUT_ASSETS=""
PROFILE=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --checked-out-assets) CHECKED_OUT_ASSETS="${2:-}"; shift 2 ;;
        --profile) PROFILE="${2:-}"; shift 2 ;;
        *) usage ;;
    esac
done

case "$CHECKED_OUT_ASSETS" in /*) ;; *) usage ;; esac
[ -d "$CHECKED_OUT_ASSETS/.git" ] || usage
case "$PROFILE" in pipeline-spike-v1|production-v1) ;; *) usage ;; esac

SOURCE_ROOT="$(cd "$CHECKED_OUT_ASSETS" && pwd -P)"
STATUS_BEFORE="$(git -C "$SOURCE_ROOT" status --porcelain=v1)"
FIRST_OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/core-box-repro-first.XXXXXX")"
SECOND_OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/core-box-repro-second.XXXXXX")"
trap 'rm -rf -- "$FIRST_OUTPUT" "$SECOND_OUTPUT"' EXIT

record_mismatch() {
    local reason="$1"
    local report_path
    report_path="$(mktemp "${TMPDIR:-/tmp}/core-box-repro-report.XXXXXX")"
    {
        echo "reason=$reason"
        echo "first=$FIRST_OUTPUT"
        echo "second=$SECOND_OUTPUT"
        find "$FIRST_OUTPUT" "$SECOND_OUTPUT" -type f -exec shasum -a 256 {} + | LC_ALL=C sort
    } > "$report_path"
    echo "core_box_repro_report: $report_path" >&2
    exit 65
}

run_export() {
    local output_root="$1"
    BLENDER_BIN="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}" \
        "$SOURCE_ROOT/scripts/core-box-export.sh" --output "$output_root" --profile "$PROFILE"
}

compare_output_trees() {
    local relative
    if ! diff -u \
        <(cd "$FIRST_OUTPUT" && find . -type f -print | LC_ALL=C sort) \
        <(cd "$SECOND_OUTPUT" && find . -type f -print | LC_ALL=C sort); then
        echo "core_box_repro_tree_mismatch" >&2
        record_mismatch "tree"
    fi
    while IFS= read -r relative; do
        if ! cmp -s "$FIRST_OUTPUT/$relative" "$SECOND_OUTPUT/$relative"; then
            echo "core_box_repro_byte_mismatch: $relative" >&2
            record_mismatch "byte:$relative"
        fi
    done < <(cd "$FIRST_OUTPUT" && find . -type f -print | LC_ALL=C sort)
}

run_export "$FIRST_OUTPUT"
run_export "$SECOND_OUTPUT"
compare_output_trees

STATUS_AFTER="$(git -C "$SOURCE_ROOT" status --porcelain=v1)"
if [ "$STATUS_BEFORE" != "$STATUS_AFTER" ]; then
    echo "core_box_repro_checkout_changed" >&2
    exit 65
fi
