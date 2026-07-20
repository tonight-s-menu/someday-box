#!/bin/bash
# Export deterministic USDA stages from the authored source.
set -eu
export TZ=UTC LANG=C LC_ALL=C SOURCE_DATE_EPOCH=946684800

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

for TIER in full lite; do
    case "${TIER}" in
        full) RESOURCE="CoreBoxCharacterFull" ;;
        lite) RESOURCE="CoreBoxCharacterLite" ;;
    esac
    SOURCE_STAGE="${OUTPUT_ROOT}/stage/${TIER}/${RESOURCE}.usda"
    NORMALIZED_STAGE="${OUTPUT_ROOT}/stage/${TIER}/${RESOURCE}.normalized.usda"
    BLENDER_BIN="${BLENDER_BIN}" "${SOURCE_ROOT}/scripts/run-core-box-blender.sh" \
        --background --factory-startup --disable-autoexec --offline-mode --python-use-system-env --python-exit-code 1 \
        --python "${SOURCE_ROOT}/Assets/CoreBoxCharacter/scripts/compose-core-box-static.py" -- \
        --source "${SOURCE_STAGE}" --output "${NORMALIZED_STAGE}"
    mv "${NORMALIZED_STAGE}" "${SOURCE_STAGE}"

    COMPOSED_STAGE="${OUTPUT_ROOT}/stage/${TIER}/${RESOURCE}.composed.usda"
    BLENDER_BIN="${BLENDER_BIN}" "${SOURCE_ROOT}/scripts/run-core-box-blender.sh" \
        --background --factory-startup --disable-autoexec --offline-mode --python-use-system-env --python-exit-code 1 \
        --python "${SOURCE_ROOT}/Assets/CoreBoxCharacter/scripts/compose-core-box-clips.py" -- \
        --base "${SOURCE_STAGE}" --output "${COMPOSED_STAGE}" --config "${SOURCE_ROOT}/Assets/CoreBoxCharacter/export-config.json" --profile "${PROFILE}"
    mv "${COMPOSED_STAGE}" "${SOURCE_STAGE}"

    # USDZ records source mtimes; normalize every packaged dependency before usdzip.
    find "${OUTPUT_ROOT}/stage/${TIER}" -type f -exec touch -t 200001010000 {} +

    /usr/bin/usdcat --loadOnly "${SOURCE_STAGE}"
    /usr/bin/usdchecker --arkit --strict "${SOURCE_STAGE}"
    # usdzip serializes an absolute input path into its converted root layer;
    # invoke it from the stage directory so that path is destination-independent.
    (
        cd "${OUTPUT_ROOT}/stage/${TIER}"
        /usr/bin/usdzip "${OUTPUT_ROOT}/${RESOURCE}.usdz" --arkitAsset "${RESOURCE}.usda"
    )
    /usr/bin/python3 -B "${SOURCE_ROOT}/scripts/normalize-usdz-timestamps.py" --package "${OUTPUT_ROOT}/${RESOURCE}.usdz"
    /usr/bin/usdchecker --arkit --strict "${OUTPUT_ROOT}/${RESOURCE}.usdz"
    /usr/bin/python3 -B "${SOURCE_ROOT}/scripts/verify-core-box-package.py" --package "${OUTPUT_ROOT}/${RESOURCE}.usdz" --tier "${TIER}"
done
