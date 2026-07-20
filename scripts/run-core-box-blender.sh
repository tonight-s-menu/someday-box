#!/usr/bin/env bash
# The only permitted launcher for a Blender process that executes Python.
#
# Usage: run-core-box-blender.sh <absolute-blender-python-script> [args...]
#
# Verifies the full toolchain contract (config/provenance pins plus live
# Xcode, Blender, macOS, and Apple USD identity) before ever starting
# Blender, then executes Blender under an empty, explicit environment
# allowlist. No caller PATH, HOME, TMPDIR, or other PYTHON* value reaches
# either Python runtime; every executable and script path passed to it is
# absolute.

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BLENDER_BIN="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"

if [ "$#" -lt 1 ]; then
    echo "usage: run-core-box-blender.sh <absolute-blender-python-script> [args...]" >&2
    exit 64
fi

BLENDER_SCRIPT="$1"
shift

case "${BLENDER_SCRIPT}" in
    /*) ;;
    *)
        echo "run-core-box-blender.sh requires an absolute Blender Python script path" >&2
        exit 64
        ;;
esac

case "${BLENDER_BIN}" in
    /*) ;;
    *)
        echo "run-core-box-blender.sh requires an absolute Blender binary path" >&2
        exit 64
        ;;
esac

if [ ! -f "${BLENDER_SCRIPT}" ]; then
    echo "run-core-box-blender.sh: no such Blender Python script: ${BLENDER_SCRIPT}" >&2
    exit 64
fi

# An optional caller DEVELOPER_DIR is copied only into the toolchain-check
# process, where exact Xcode output is still verified; it never reaches
# Blender.
CALLER_DEVELOPER_DIR="${DEVELOPER_DIR:-}"

env -i \
    DEVELOPER_DIR="${CALLER_DEVELOPER_DIR}" \
    TZ=UTC \
    LC_ALL=C \
    LANG=C \
    PYTHONDONTWRITEBYTECODE=1 \
    /usr/bin/python3 -B "${REPO_ROOT}/scripts/core_box_toolchain.py" \
    --source-root "${REPO_ROOT}" --scope full --blender "${BLENDER_BIN}"

exec env -i \
    TZ=UTC \
    LC_ALL=C \
    LANG=C \
    SOURCE_DATE_EPOCH=946684800 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONHASHSEED=0 \
    PYTHONNOUSERSITE=1 \
    PYTHONPATH= \
    PYTHONHOME= \
    PYTHONUSERBASE= \
    "${BLENDER_BIN}" --background --factory-startup --python "${BLENDER_SCRIPT}" -- "$@"
