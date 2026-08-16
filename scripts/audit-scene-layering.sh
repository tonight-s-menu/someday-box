#!/usr/bin/env bash
set -euo pipefail

# Enforces the layer placement ADR 0004 fixes for the Lived-in Box scene:
# rendering, audio, and haptics frameworks belong to the scene module inside the
# Features layer, and nowhere else. This audit is source-and-project scan only; it
# does not prove runtime behaviour, device rendering, or packaged acceptance.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_FILE="${REPOSITORY_ROOT}/SomedayBox.xcodeproj/project.pbxproj"
readonly SCENE_MODULE="Features/Home/Scene"
readonly SCENE_FRAMEWORK_IMPORT='^[[:space:]]*import[[:space:]]+(RealityKit|RealityFoundation|_RealityKit_SwiftUI|AVFAudio|AVFoundation|CoreHaptics)([[:space:]]|$)'
readonly PRESENTATION_IMPORT='^[[:space:]]*import[[:space:]]+(SwiftUI|SwiftUICore|UIKit)([[:space:]]|$)'

failures=0

pass() {
    echo "[scene layering audit] PASS: $1"
}

fail() {
    echo "[scene layering audit] FAIL: $1" >&2
    failures=$((failures + 1))
}

cd "${REPOSITORY_ROOT}"

readonly -a NON_SCENE_SOURCE_ROOTS=(App Application Data Domain DesignSystem Features ShareExtension)

if matches="$(rg -n --glob '*.swift' --glob "!${SCENE_MODULE}/**" --regexp "${SCENE_FRAMEWORK_IMPORT}" "${NON_SCENE_SOURCE_ROOTS[@]}")"; then
    fail "rendering, audio, and haptics frameworks are imported only inside ${SCENE_MODULE}"
    echo "${matches}" >&2
else
    pass "rendering, audio, and haptics frameworks are imported only inside ${SCENE_MODULE}"
fi

if matches="$(rg -n --glob '*.swift' --regexp "${SCENE_FRAMEWORK_IMPORT}" ShareExtension)"; then
    fail "Share Extension sources import no rendering, audio, or haptics framework"
    echo "${matches}" >&2
else
    pass "Share Extension sources import no rendering, audio, or haptics framework"
fi

if matches="$(rg -n --glob '*.swift' --regexp "${PRESENTATION_IMPORT}" Domain Application)"; then
    fail "Domain and Application sources import no presentation framework"
    echo "${matches}" >&2
else
    pass "Domain and Application sources import no presentation framework"
fi

# The Xcode project lists every source file explicitly, so a new scene file that is
# never registered would compile in no target at all and fail silently.
if [[ -d "${SCENE_MODULE}" ]]; then
    unregistered=0
    while IFS= read -r scene_file; do
        scene_file_name="$(basename "${scene_file}")"
        if ! rg -q --fixed-strings "path = ${scene_file_name};" "${PROJECT_FILE}"; then
            fail "${scene_file} is registered in the Xcode project"
            unregistered=$((unregistered + 1))
        fi
    done < <(rg --files -g '*.swift' "${SCENE_MODULE}")
    if (( unregistered == 0 )); then
        pass "every scene source file is registered in the Xcode project"
    fi
else
    fail "${SCENE_MODULE} exists"
fi

if (( failures > 0 )); then
    echo "[scene layering audit] ${failures} check(s) failed." >&2
    exit 1
fi

echo "[scene layering audit] Scene layer placement audit passed."
