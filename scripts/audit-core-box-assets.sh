#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

manifest="Resources/CoreBoxAssetManifest.json"
full="Resources/CoreBoxCharacterFull.usdz"
lite="Resources/CoreBoxCharacterLite.usdz"
identity="Generated/CoreBoxAssetIdentity.generated.swift"

for path in "${manifest}" "${full}" "${lite}" "${identity}"; do
    if [[ ! -s "${path}" ]]; then
        echo "[core-box asset audit] FAIL: missing sealed production artifact ${path}." >&2
        exit 1
    fi
done

/usr/bin/python3 -B - "${manifest}" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
required = {
    "assetVersion", "authoringTreeSHA256", "animationEncoding", "clips",
    "parameterizedChannels", "tiers", "provenance",
}
missing = sorted(required - manifest.keys())
if missing:
    raise SystemExit(f"manifest_missing_keys:{','.join(missing)}")
names = [clip["name"] for clip in manifest["clips"]]
expected = [
    "idle.blink", "idle.listen", "idle.paperRustle", "idle.currentGlance",
    "react.touch", "react.notice.single", "react.notice.aggregate",
    "capture.receive", "capture.deposit", "draw.reveal", "current.attach",
    "paper.return", "memory.stamp",
]
if names != expected:
    raise SystemExit(f"production_motion_set_mismatch:{names!r}")
if manifest["animationEncoding"] not in {"usdNamedResourcesV1", "runtimeTransformRecipesV1"}:
    raise SystemExit("unsupported_animation_encoding")
channel = next((item for item in manifest["parameterizedChannels"] if item["name"] == "ribbon.pull"), None)
if channel is None or channel["samples"] != [0.0, 0.72, 1.0]:
    raise SystemExit("ribbon_pull_contract_mismatch")
if manifest["provenance"].get("remoteDependencies") is not False:
    raise SystemExit("remote_dependencies_not_allowed")
PY

if rg -n 'makeCoreBoxScene|CoreBox\.usda' App Application Data Domain Features DesignSystem ShareExtension SomedayBox.xcodeproj/project.pbxproj; then
    echo "[core-box asset audit] FAIL: obsolete production primitive or USDA path remains." >&2
    exit 1
fi

echo "[core-box asset audit] Sealed production manifest, Full/Lite packages, identity, motion vocabulary, and source hard-cut passed."
