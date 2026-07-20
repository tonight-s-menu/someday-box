#!/bin/bash
# Export static USDA stages only; composition and USDZ sealing are the next task slice.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BLENDER_BIN="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"

OUTPUT_ROOT=""
PROFILE=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) OUTPUT_ROOT="${2:-}"; shift 2 ;;
        --profile) PROFILE="${2:-}"; shift 2 ;;
        *) echo "usage: core-box-export.sh --output ABSOLUTE_DIRECTORY --profile PROFILE" >&2; exit 64 ;;
    esac
done

case "${OUTPUT_ROOT}" in /*) ;; *) echo "output must be absolute" >&2; exit 64 ;; esac
[ -n "${PROFILE}" ] || { echo "profile is required" >&2; exit 64; }
mkdir -p "${OUTPUT_ROOT}"

env -i TZ=UTC LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B \
    "${SOURCE_ROOT}/Assets/CoreBoxCharacter/scripts/validate-core-box-export-request.py" \
    --config "${SOURCE_ROOT}/Assets/CoreBoxCharacter/export-config.json" --output "${OUTPUT_ROOT}" --profile "${PROFILE}" >/dev/null

env -i TZ=UTC LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B \
    "${SOURCE_ROOT}/scripts/core_box_toolchain.py" --source-root "${SOURCE_ROOT}" --scope full --blender "${BLENDER_BIN}"

BLENDER_BIN="${BLENDER_BIN}" "${SOURCE_ROOT}/scripts/run-core-box-blender.sh" \
    --background --factory-startup --disable-autoexec --offline-mode --python-use-system-env --python-exit-code 1 \
    "${SOURCE_ROOT}/Assets/CoreBoxCharacter/CoreBoxCharacter.blend" \
    --python "${SOURCE_ROOT}/Assets/CoreBoxCharacter/scripts/export-core-box.py" -- \
    --config "${SOURCE_ROOT}/Assets/CoreBoxCharacter/export-config.json" --output "${OUTPUT_ROOT}" --profile "${PROFILE}"
